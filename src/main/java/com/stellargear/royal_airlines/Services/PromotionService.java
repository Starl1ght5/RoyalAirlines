package com.stellargear.royal_airlines.Services;

import com.stellargear.royal_airlines.Models.DTOs.PromotionDTO;
import com.stellargear.royal_airlines.Models.Entities.Flight;
import com.stellargear.royal_airlines.Models.Entities.Location;
import com.stellargear.royal_airlines.Models.Entities.Promotion;
import com.stellargear.royal_airlines.Models.Enums.FlightStatus;
import com.stellargear.royal_airlines.Repositories.FlightRepository;
import com.stellargear.royal_airlines.Repositories.LocationRepository;
import com.stellargear.royal_airlines.Repositories.PromotionRepository;
import com.stellargear.royal_airlines.Utils.MoneyExchange;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.text.Normalizer;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

/**
 * Promociones del slider de Home, derivadas de los vuelos que ya existen en la base.
 *
 * <p>Nada se escribe a mano: el servicio toma los vuelos ACTIVE de los proximos 90 dias, los
 * agrupa por ruta (origen-destino), puntua cada ruta y publica las {@value #TOP_N} mejores como
 * documentos {@code Promotions}. El puntaje mezcla cuatro senales que YA estan en {@code Flights}
 * y {@code Destinations}:</p>
 *
 * <ul>
 *   <li><b>descuento</b> ({@code Flight.discountPercentage} o el que se deduce de
 *       {@code basePrice > ticketPrice}): la ruta con descuento se publica como "Hasta X% OFF";</li>
 *   <li><b>precio</b>: la ruta mas barata de la muestra puntua 1.0 y se publica
 *       "Desde COP ..." ya convertido con {@link MoneyExchange};</li>
 *   <li><b>vuelo directo</b> ({@code Flight.scales == 0}): cambia el subtitle a
 *       "Vuelos directos desde ...";</li>
 *   <li><b>destino featured</b> ({@code Location.featured}, el trending de
 *       {@link TrendingFeaturedService}): los destinos de moda pesan mas.</li>
 * </ul>
 *
 * <p>Dos reglas anti-repeticion: una UNICA tarjeta por ciudad destino (el ranking elige que
 * ruta la representa, para que no salga "Ofertas a Barranquilla" dos veces) y el "% OFF" solo
 * en la mejor oferta de la muestra, para que las seis tarjetas no repitan el mismo badge.</p>
 *
 * <p>Cada tarjeta ademas lleva la ruta ({@code origin}/{@code destination}) y la fecha del vuelo
 * mas barato ({@code departureDate}): al tocarla, el front navega a la pantalla de resultados
 * con esa busqueda, que siempre aterriza en un dia con vuelos reales.</p>
 *
 * <p>Cuando se refresca: un cron diario (03:55 de Bogota, despues del snapshot de precios de las
 * 03:30 y del refresh de trending de las 03:45), al servir si los documentos tienen mas de
 * {@value #STALE_AFTER_HOURS} horas, y bajo demanda via
 * {@code POST /internal/promotions/refresh}. Si no hay NINGUN vuelo utilizable no se borra nada:
 * se conservan las promociones actuales (mismo guardrail que {@link TrendingFeaturedService}).</p>
 *
 * <p>La toma de decision es {@link #select} y la redaccion de cada tarjeta {@link #toPromotion},
 * ambas puras: se prueban sin MongoDB.</p>
 */
@Service
@RequiredArgsConstructor
public class PromotionService {

    private static final Logger logger = LoggerFactory.getLogger(PromotionService.class);

    /** Promociones que ve el slider. */
    static final int TOP_N = 6;

    /**
     * Tarjetas por ciudad destino: UNA sola, elegida entre sus rutas con mejor puntaje.
     *
     * <p>Con dos, el slider ponia el mismo titulo dos veces ("Ofertas a Barranquilla" desde
     * Santa Marta y desde Cartagena): para una persona que hojea las tarjetas eso es una
     * promocion repetida, aunque detras haya dos rutas distintas.</p>
     */
    static final int MAX_PER_DESTINATION = 1;

    /** Horas que pasan antes de que se vuelva a calcular la coleccion al servir. */
    static final int STALE_AFTER_HOURS = 6;

    /** Dias hacia adelante que se miran los vuelos (igual que el snapshot de precios). */
    static final int DAYS_AHEAD = 90;

    /** Ponderaciones del puntaje: suman 1.0. */
    static final double WEIGHT_DISCOUNT = 0.30;
    static final double WEIGHT_PRICE = 0.30;
    static final double WEIGHT_DIRECT = 0.15;
    static final double WEIGHT_FEATURED = 0.25;

    /** Descuento de 50% o mas ya puntua 1.0; mas alla de eso no aporta mas ranking. */
    static final double DISCOUNT_REFERENCE = 50.0;

    /** Descuento minimo (en %) para que la tarjeta se publique como oferta. */
    static final double MIN_DISCOUNT_FOR_LABEL = 5.0;

    private final PromotionRepository promotionRepository;
    private final FlightRepository flightRepository;
    private final LocationRepository locationRepository;
    private final MoneyExchange moneyExchange;

    /** Ruta (origen, destino) resumida: decide el ranking y redacta la tarjeta. */
    record RouteStat(String originIata, String destinationIata, String originCity,
                     String destinationCity, long priceCop, int flightCount,
                     double maxDiscountPct, boolean direct, boolean featured,
                     LocalDate departureDate) {}

    /** Resultado del refresh, para el log y para el endpoint manual. */
    public record RefreshResult(int routesEvaluated, int promotions, List<String> removed,
                                boolean skipped) {}

    /**
     * Promociones activas para el slider, en el orden en que deben mostrarse.
     *
     * <p>Antes de responder comprueba la frescura de la coleccion: si esta vacia o algun documento
     * pasa de {@value #STALE_AFTER_HOURS} horas se regenera, de modo que un despliegue o un lote
     * de vuelos nuevos no dependa de esperar al cron.</p>
     *
     * @return promociones activas convertidas a DTO (nunca {@code null}: sin promociones el slider
     *         simplemente no se renderiza).
     */
    public List<PromotionDTO> getActivePromotions() {
        if (isStale(promotionRepository.findAll())) {
            refresh();
        }

        return promotionRepository.findByActiveTrueOrderBySortOrderAsc().stream()
                .map(PromotionService::toDto)
                .toList();
    }

    /**
     * Refresco programado. Cron configurable con {@code royal.promotions.refresh-cron} (por
     * defecto 03:55 de Bogota, despues del snapshot de precios y del refresh de trending).
     *
     * @return resumen del calculo.
     */
    @Scheduled(cron = "${royal.promotions.refresh-cron:0 55 3 * * *}", zone = "America/Bogota")
    public RefreshResult refresh() {
        LocalDateTime now = LocalDateTime.now();
        List<Flight> flights = flightRepository.findByStatusAndDepartureDateBetween(
                FlightStatus.ACTIVE, now, now.plusDays(DAYS_AHEAD));

        Map<String, Location> locationsById = locationRepository.findAll().stream()
                .filter(location -> location.getLocationID() != null)
                .collect(Collectors.toMap(Location::getLocationID, location -> location,
                        (first, second) -> first));

        List<RouteStat> routes = buildRouteStats(flights, locationsById, moneyExchange);
        List<RouteStat> selected = select(routes);

        if (selected.isEmpty()) {
            logger.warn("Promotions: sin vuelos utilizables ({} rutas evaluadas); se conservan las promociones actuales",
                    routes.size());
            return new RefreshResult(routes.size(), 0, List.of(), true);
        }

        // active=false escrito a mano (por ejemplo desde la base) se respeta en el refresh.
        Map<String, Boolean> activeBefore = promotionRepository.findAll().stream()
                .filter(promotion -> promotion.id() != null)
                .collect(Collectors.toMap(Promotion::id, Promotion::active, (first, second) -> first));

        Instant generatedAt = Instant.now();
        RouteStat topOffer = bestOffer(selected);
        List<Promotion> generated = new ArrayList<>();
        for (int index = 0; index < selected.size(); index++) {
            RouteStat route = selected.get(index);
            generated.add(toPromotion(route, index + 1, route.equals(topOffer),
                    activeBefore.getOrDefault(idFor(route), true), generatedAt));
        }

        List<String> generatedIds = generated.stream().map(Promotion::id).toList();
        List<String> removed = promotionRepository.findAll().stream()
                .map(Promotion::id)
                .filter(Objects::nonNull)
                .filter(id -> !generatedIds.contains(id))
                .toList();

        promotionRepository.saveAll(generated);
        if (!removed.isEmpty()) {
            promotionRepository.deleteAllById(removed);
        }

        logger.info("Promotions: {} rutas evaluadas -> {} promociones ({} retiradas)",
                routes.size(), generated.size(), removed.size());
        return new RefreshResult(routes.size(), generated.size(), removed, false);
    }

    /** Coleccion vacia o con documentos de mas de {@value #STALE_AFTER_HOURS} horas. */
    static boolean isStale(List<Promotion> promotions) {
        if (promotions.isEmpty()) {
            return true;
        }

        Instant cutoff = Instant.now().minus(Duration.ofHours(STALE_AFTER_HOURS));
        return promotions.stream().anyMatch(promotion ->
                promotion.generatedAt() == null || promotion.generatedAt().isBefore(cutoff));
    }

    /**
     * Resume los vuelos proximos por ruta (origen-destino).
     *
     * <p>Solo cuenta vuelos con fecha y precio validos cuyo origen y destino existan en el
     * catalogo; de cada ruta guarda el precio mas barato (ya en COP) junto con la FECHA de ese
     * vuelo (la que la tarjeta usara para buscar al ser tocada), cuantos vuelos tiene, el
     * mayor descuento entre ellos y si alguno es directo.</p>
     *
     * @param flights vuelos a evaluar.
     * @param locationsById indice de {@code Location.locationID}.
     * @param exchange conversor USD a COP.
     * @return una fila por ruta con datos.
     */
    static List<RouteStat> buildRouteStats(List<Flight> flights, Map<String, Location> locationsById,
                                           MoneyExchange exchange) {
        Map<String, RouteAccumulator> byRoute = new LinkedHashMap<>();

        for (Flight flight : flights) {
            if (flight.getDepartureDate() == null || flight.getTicketPrice() <= 0) {
                continue;
            }

            Location origin = locationsById.get(flight.getDepartureLocationID());
            Location destination = locationsById.get(flight.getArrivalLocationID());
            if (origin == null || destination == null) {
                continue;
            }

            String originIata = iataOf(origin);
            String destinationIata = iataOf(destination);
            if (originIata == null || destinationIata == null) {
                continue;
            }

            RouteAccumulator accumulator = byRoute.computeIfAbsent(
                    originIata + "_" + destinationIata,
                    key -> new RouteAccumulator(originIata, destinationIata, origin, destination));

            accumulator.flightCount++;
            if (flight.getTicketPrice() < accumulator.minPriceUsd) {
                // La fecha se guarda junto al precio porque es EL vuelo que publica la
                // tarjeta: al tocarla, el front busca ese dia y siempre encuentra vuelos.
                accumulator.minPriceUsd = flight.getTicketPrice();
                accumulator.departureDate = flight.getDepartureDate().toLocalDate();
            }
            accumulator.maxDiscountPct = Math.max(accumulator.maxDiscountPct, discountPercent(flight));
            accumulator.direct = accumulator.direct || flight.isDirect();
        }

        return byRoute.values().stream()
                .map(accumulator -> new RouteStat(
                        accumulator.originIata,
                        accumulator.destinationIata,
                        cityOrIata(accumulator.origin),
                        cityOrIata(accumulator.destination),
                        exchange.convertUSDtoCOP(accumulator.minPriceUsd).getAmount().longValue(),
                        accumulator.flightCount,
                        accumulator.maxDiscountPct,
                        accumulator.direct,
                        accumulator.destination.isFeatured(),
                        accumulator.departureDate))
                .toList();
    }

    /**
     * IATA normalizado (sin espacios ni minusculas): dos aeropuertos que se escriben distinto
     * deben quedar en la MISMA ruta, no en dos tarjetas casi identicas.
     *
     * @param location destino u origen.
     * @return codigo en mayusculas o {@code null} si no tiene.
     */
    static String iataOf(Location location) {
        String iata = location.getIataCode();
        return iata == null || iata.isBlank() ? null : iata.trim().toUpperCase(Locale.ROOT);
    }

    /**
     * Descuento del vuelo en porcentaje.
     *
     * <p>Usa {@code discountPercentage} cuando el vuelo esta marcado como descontado; si no, lo
     * deduce de la diferencia entre {@code basePrice} y {@code ticketPrice} (hay vuelos con
     * precio rebajado sin la bandera encendida).</p>
     *
     * @param flight vuelo a evaluar.
     * @return descuento en %, o 0 si no tiene.
     */
    static double discountPercent(Flight flight) {
        if (flight.isDiscounted() && flight.getDiscountPercentage() > 0) {
            return flight.getDiscountPercentage();
        }

        if (flight.getBasePrice() > flight.getTicketPrice() && flight.getBasePrice() > 0) {
            return (flight.getBasePrice() - flight.getTicketPrice()) / flight.getBasePrice() * 100;
        }

        return 0;
    }

    /**
     * Elige que rutas se publican y en que orden.
     *
     * <p>Puntua cada ruta con {@link #score}, ordena de mayor a menor (con desempate estable por
     * destino y origen) y corta en el top-N dejando UNA tarjeta por ciudad destino (ver
     * {@link #cityKey}): el ranking escoge que ruta representa a esa ciudad. Puro: sin MongoDB
     * ni estado.</p>
     *
     * @param routes rutas evaluadas.
     * @return rutas seleccionadas, en orden de mostrado.
     */
    static List<RouteStat> select(List<RouteStat> routes) {
        if (routes.isEmpty()) {
            return List.of();
        }

        long minPrice = routes.stream().mapToLong(RouteStat::priceCop).min().orElse(0);
        long maxPrice = routes.stream().mapToLong(RouteStat::priceCop).max().orElse(0);

        List<RouteStat> ranked = routes.stream()
                .sorted(Comparator.comparingDouble((RouteStat route) -> score(route, minPrice, maxPrice))
                        .reversed()
                        .thenComparing(RouteStat::destinationIata)
                        .thenComparing(RouteStat::originIata))
                .toList();

        List<RouteStat> selected = new ArrayList<>();
        Map<String, Integer> perDestination = new HashMap<>();

        for (RouteStat route : ranked) {
            if (selected.size() >= TOP_N) {
                break;
            }

            String destination = cityKey(route.destinationCity());
            int alreadySelected = perDestination.getOrDefault(destination, 0);
            if (alreadySelected >= MAX_PER_DESTINATION) {
                continue;
            }

            perDestination.put(destination, alreadySelected + 1);
            selected.add(route);
        }

        return selected;
    }

    /**
     * Llave de ciudad para no repetir tarjetas: "Bogota" y "Bogotá" son la misma ciudad.
     *
     * @param city nombre de la ciudad (puede venir con tildes, espacios o en minusculas).
     * @return llave normalizada.
     */
    static String cityKey(String city) {
        String normalized = city == null ? "" : city.trim();
        return Normalizer.normalize(normalized, Normalizer.Form.NFD)
                .replaceAll("\\p{M}", "")
                .toLowerCase(Locale.ROOT);
    }

    /**
     * La ruta con el mejor descuento de la seleccion: esa tarjeta es la unica que lleva el
     * porcentaje en el badge. Las demas muestran el precio, que es lo que de verdad cambia de
     * una ruta a otra (con descuentos parejos en todo el catalogo, repetir "Hasta 30% OFF" en
     * las seis tarjetas no le dice nada a la persona).
     *
     * <p>En empate gana la primera en orden de puntaje, que es como viene ordenada la
     * seleccion.</p>
     *
     * @param routes rutas seleccionadas, en orden de mostrado.
     * @return la mejor oferta o {@code null} si ninguna llega al minimo de descuento.
     */
    static RouteStat bestOffer(List<RouteStat> routes) {
        return routes.stream()
                .filter(route -> route.maxDiscountPct() >= MIN_DISCOUNT_FOR_LABEL)
                .max(Comparator.comparingDouble(RouteStat::maxDiscountPct))
                .orElse(null);
    }

    /**
     * Puntaje de una ruta, de 0.0 a 1.0: descuento + baratura + directo + featured.
     *
     * @param route ruta a puntuar.
     * @param minPrice precio mas barato de la muestra (normalizacion).
     * @param maxPrice precio mas caro de la muestra (normalizacion).
     * @return puntaje, mayor es mejor.
     */
    static double score(RouteStat route, long minPrice, long maxPrice) {
        double discount = Math.min(Math.max(route.maxDiscountPct(), 0), DISCOUNT_REFERENCE)
                / DISCOUNT_REFERENCE;
        double price = maxPrice > minPrice
                ? 1.0 - (route.priceCop() - minPrice) / (double) (maxPrice - minPrice)
                : 1.0;

        return WEIGHT_DISCOUNT * discount
                + WEIGHT_PRICE * price
                + (route.direct() ? WEIGHT_DIRECT : 0)
                + (route.featured() ? WEIGHT_FEATURED : 0);
    }

    /**
     * Redacta la tarjeta de una ruta seleccionada.
     *
     * <p>Dos mensajes separados: el TITULO dice si la ruta esta en promocion (descuento de 5% o
     * mas &rarr; "Ofertas a ..."; si no, "{Ciudad} desde") y el BADGE lleva el porcentaje
     * SOLO en la mejor oferta de la muestra ({@link #bestOffer}); en el resto el badge pone
     * el precio, que es lo que varia de una tarjeta a otra. El subtitle siempre dice de que
     * origen salen y si son directos, que es lo que la ruta permite afirmar.</p>
     *
     * @param route ruta seleccionada.
     * @param sortOrder posicion en el slider, empezando en 1.
     * @param highlightDiscount si el badge debe llevar el "% OFF" en vez del precio.
     * @param active estado inicial (respeta una desactivacion manual previa).
     * @param generatedAt momento del calculo.
     * @return promocion lista para guardar.
     */
    static Promotion toPromotion(RouteStat route, int sortOrder, boolean highlightDiscount,
                                 boolean active, Instant generatedAt) {
        boolean inCampaign = route.maxDiscountPct() >= MIN_DISCOUNT_FOR_LABEL;
        String title = inCampaign
                ? "Ofertas a " + route.destinationCity()
                : route.destinationCity() + " desde";
        String subtitle = (route.direct() ? "Vuelos directos desde " : "Vuelos desde ")
                + route.originCity();
        String discountLabel = highlightDiscount
                ? "Hasta " + Math.round(route.maxDiscountPct()) + "% OFF"
                : "Desde COP " + compactCop(route.priceCop());

        return new Promotion(idFor(route), title, subtitle, discountLabel,
                route.originIata(), route.destinationIata(), route.departureDate(),
                active, sortOrder, generatedAt);
    }

    /** Id estable por ruta: dos refreshes seguidos actualizan el mismo documento. */
    static String idFor(RouteStat route) {
        return "promo_" + route.originIata() + "_" + route.destinationIata();
    }

    /**
     * Precio compacto para el label, igual que en el mock del front: 245000 &rarr; "245K",
     * 1200000 &rarr; "1.2M".
     *
     * @param cop precio en pesos.
     * @return texto corto.
     */
    static String compactCop(long cop) {
        if (cop >= 1_000_000L) {
            String millions = BigDecimal.valueOf(cop)
                    .divide(BigDecimal.valueOf(1_000_000L), 1, RoundingMode.HALF_UP)
                    .stripTrailingZeros()
                    .toPlainString();
            return millions + "M";
        }

        if (cop >= 1_000L) {
            return Math.round(cop / 1000.0) + "K";
        }

        return String.valueOf(cop);
    }

    private static String cityOrIata(Location location) {
        return location.getCityName() == null || location.getCityName().isBlank()
                ? location.getIataCode()
                : location.getCityName();
    }

    private static PromotionDTO toDto(Promotion promotion) {
        return new PromotionDTO(
                promotion.id(),
                promotion.title(),
                promotion.subtitle(),
                promotion.discountLabel(),
                promotion.origin(),
                promotion.destination(),
                promotion.departureDate(),
                promotion.active());
    }

    /** Acumulador de una ruta durante el barrido de vuelos. */
    private static final class RouteAccumulator {
        private final String originIata;
        private final String destinationIata;
        private final Location origin;
        private final Location destination;
        private double minPriceUsd = Double.MAX_VALUE;
        private LocalDate departureDate;
        private int flightCount;
        private double maxDiscountPct;
        private boolean direct;

        private RouteAccumulator(String originIata, String destinationIata, Location origin,
                                 Location destination) {
            this.originIata = originIata;
            this.destinationIata = destinationIata;
            this.origin = origin;
            this.destination = destination;
        }
    }
}
