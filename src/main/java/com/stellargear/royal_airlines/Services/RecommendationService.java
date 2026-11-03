package com.stellargear.royal_airlines.Services;

import com.stellargear.royal_airlines.Models.DTOs.RecommendationItem;
import com.stellargear.royal_airlines.Models.DTOs.RecommendationListDTO;
import com.stellargear.royal_airlines.Models.DTOs.UserRecommendationDocDTO;
import com.stellargear.royal_airlines.Models.Entities.Flight;
import com.stellargear.royal_airlines.Models.Entities.Location;
import com.stellargear.royal_airlines.Models.Entities.UserRecommendation;
import com.stellargear.royal_airlines.Models.Enums.FlightStatus;
import com.stellargear.royal_airlines.Models.Enums.LocationStatus;
import com.stellargear.royal_airlines.Repositories.FlightRepository;
import com.stellargear.royal_airlines.Repositories.LocationRepository;
import com.stellargear.royal_airlines.Repositories.UserRecommendationRepository;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

/**
 * Sirve las recomendaciones precalculadas por Python y, cuando aun no existen, construye un
 * respaldo de populares y ofertas con los datos que ya tiene el backend.
 *
 * <p>El orden de lectura es: lista del usuario, luego la de {@code __popular__}, y solo si
 * ninguna existe (job que nunca corrio) se calcula el respaldo al vuelo. Asi la app nunca
 * falla por falta de recomendaciones.</p>
 */
@Service
@RequiredArgsConstructor
public class RecommendationService {

    /** _id del documento de respaldo general que escribe el job de Python. */
    public static final String POPULAR_ID = "__popular__";

    private static final Logger logger = LoggerFactory.getLogger(RecommendationService.class);
    private static final int FALLBACK_TOP_K = 10;
    private static final int LEAD_DAYS = 45;

    private final UserRecommendationRepository recommendationRepository;
    private final LocationRepository locationRepository;
    private final FlightRepository flightRepository;

    /**
     * Lista de recomendaciones del usuario con sus respaldos.
     *
     * @param userID identificador del usuario autenticado.
     * @return lista propia, la general o el respaldo calculado al vuelo.
     */
    public RecommendationListDTO forUser(String userID) {
        UserRecommendation recommendation = recommendationRepository.findById(userID)
                .or(() -> recommendationRepository.findById(POPULAR_ID))
                .orElseGet(this::fallback);

        logger.debug("Recomendaciones para {} con estrategia {}", userID, recommendation.getStrategy());
        return toDto(recommendation);
    }

    /**
     * Borra la lista precalculada del usuario para que deje de servirse desactualizada.
     *
     * <p>Lo usan los cambios que alteran su perfil (preferencias): despues Spring intenta
     * recalcularla en caliente con el microservicio y, si este no responde, hasta el
     * proximo job la app sirve {@code __popular__}.</p>
     *
     * @param userID identificador del usuario.
     */
    public void invalidateUser(String userID) {
        recommendationRepository.deleteById(userID);
        logger.debug("Lista precalculada de {} invalidada", userID);
    }

    /**
     * Guarda (reemplazando) un lote de listas enviado por el microservicio Python.
     *
     * <p>Es la via de escritura del contrato «Python empuja, Spring guarda», para cuando se
     * prefiere que solo Spring toque MongoDB.</p>
     *
     * @param documents documentos con su {@code _id} y su ranking.
     * @return numero de listas guardadas.
     * @throws IllegalArgumentException si falta {@code _id} o {@code items}.
     */
    public int saveBulk(List<UserRecommendationDocDTO> documents) {
        List<UserRecommendation> entities = new ArrayList<>();

        for (UserRecommendationDocDTO document : documents) {
            if (document.id() == null || document.id().isBlank() || document.items() == null) {
                throw new IllegalArgumentException("Cada documento necesita _id e items");
            }

            UserRecommendation entity = new UserRecommendation();
            entity.setId(document.id());
            entity.setStrategy(document.strategy());
            entity.setModelVersion(document.modelVersion());
            entity.setRecommendationID(document.recommendationID());
            entity.setGeneratedAt(document.generatedAt());
            entity.setAsOf(document.asOf());
            entity.setItems(document.items());
            entities.add(entity);
        }

        recommendationRepository.saveAll(entities);
        logger.info("Bulk de recomendaciones guardado: {} listas", entities.size());
        return entities.size();
    }

    /**
     * Respaldo cuando el job de Python nunca corrio: populares (vuelos futuros por destino)
     * mas ofertas (descuento vigente), con la misma formula del ranking popular de Python.
     *
     * @return lista estrategia {@code fallback} lista para el cliente.
     */
    public UserRecommendation fallback() {
        LocalDateTime now = LocalDateTime.now();

        Map<String, Integer> flightCount = new HashMap<>();
        Map<String, Double> bestOffer = new HashMap<>();

        List<Flight> upcoming = flightRepository.findAll().stream()
                .filter(f -> f.getStatus() == FlightStatus.ACTIVE)
                .filter(f -> f.getDepartureDate() != null && !f.getDepartureDate().isBefore(now))
                .toList();

        // Sin vuelos futuros se relaja a cualquier vuelo activo, como hace el job de Python.
        List<Flight> source = upcoming.isEmpty()
                ? flightRepository.findAll().stream()
                        .filter(f -> f.getStatus() == FlightStatus.ACTIVE).toList()
                : upcoming;

        for (Flight flight : source) {
            String destinationID = flight.getArrivalLocationID();
            flightCount.merge(destinationID, 1, Integer::sum);

            if (flight.isDiscounted()) {
                bestOffer.merge(destinationID, flight.getDiscountPercentage(), Math::max);
            }
        }

        List<Location> visible = locationRepository.findAll().stream()
                .filter(location -> location.getStatus() != LocationStatus.HIDDEN)
                .toList();

        int maxCount = flightCount.values().stream().mapToInt(Integer::intValue).max().orElse(0);
        int targetMonth = now.plusDays(LEAD_DAYS).getMonthValue();

        List<RecommendationItem> items = new ArrayList<>();

        for (Location location : visible) {
            int count = flightCount.getOrDefault(location.getLocationID(), 0);

            // Sin ningun vuelo (o sin ninguno con oferta) no se recomienda: no se puede reservar.
            if (maxCount > 0 && count == 0) {
                continue;
            }

            double popularity = maxCount > 0 ? (double) count / maxCount : 0.0;
            double season = seasonScore(location, targetMonth);
            double offer = Math.min(Math.max((bestOffer.getOrDefault(location.getLocationID(), 0.0)) / 100.0, 0.0), 1.0);
            double featured = location.isFeatured() ? 1.0 : 0.0;

            double score = 0.60 * popularity + 0.25 * season + 0.10 * offer + 0.05 * featured;

            List<String> reasons = new ArrayList<>();
            reasons.add("POPULAR");
            if (season >= 1.0) {
                reasons.add("IN_SEASON");
            }
            if (offer >= 0.15) {
                reasons.add("OFFER");
            }
            if (featured > 0.0) {
                reasons.add("FEATURED");
            }

            items.add(new RecommendationItem(
                    location.getLocationID(),
                    location.getIataCode(),
                    location.getCityName(),
                    round(score),
                    Map.of("affinity", 0.0, "budget", 0.5, "season", round(season), "offer", round(offer)),
                    List.of(),
                    reasons));
        }

        items.sort(Comparator.comparingDouble(RecommendationItem::score).reversed());

        UserRecommendation fallback = new UserRecommendation();
        fallback.setId(POPULAR_ID);
        fallback.setStrategy("fallback");
        fallback.setModelVersion("fallback-v1");
        fallback.setRecommendationID(UUID.randomUUID().toString().replace("-", ""));
        fallback.setGeneratedAt(now);
        fallback.setItems(items.subList(0, Math.min(FALLBACK_TOP_K, items.size())));

        logger.info("Respaldo de recomendaciones calculado al vuelo: {} destinos", fallback.getItems().size());
        return fallback;
    }

    /** Puntaje de temporada identico al de {@code recommender/seasons.py}. */
    private double seasonScore(Location location, int month) {
        List<Integer> bestMonths = location.getBestMonths();

        if (bestMonths == null || bestMonths.isEmpty()) {
            return 0.5;
        }
        if (bestMonths.size() == 12 || bestMonths.contains(month)) {
            return 1.0;
        }

        int previous = Math.floorMod(month - 2, 12) + 1;
        int following = Math.floorMod(month, 12) + 1;
        return (bestMonths.contains(previous) || bestMonths.contains(following)) ? 0.5 : 0.0;
    }

    private RecommendationListDTO toDto(UserRecommendation entity) {
        List<RecommendationItem> items = entity.getItems() == null ? List.of() : entity.getItems();

        return new RecommendationListDTO(
                entity.getStrategy(),
                entity.getModelVersion(),
                entity.getRecommendationID(),
                entity.getGeneratedAt(),
                items);
    }

    private static double round(double value) {
        return Math.round(value * 10000.0) / 10000.0;
    }
}
