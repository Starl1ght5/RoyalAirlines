package com.stellargear.royal_airlines.Controllers;

import com.stellargear.royal_airlines.Models.DTOs.UserRecommendationDocDTO;
import com.stellargear.royal_airlines.Services.FlightService;
import com.stellargear.royal_airlines.Services.OfferNotificationService;
import com.stellargear.royal_airlines.Services.PromotionService;
import com.stellargear.royal_airlines.Services.RecommendationService;
import com.stellargear.royal_airlines.Services.TrendingFeaturedService;
import com.stellargear.royal_airlines.Utils.BadRequestException;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Positive;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.bson.Document;
import org.bson.types.ObjectId;
import org.springframework.data.domain.Sort;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Contrato servidor-servidor con el microservicio Python, protegido con {@code X-API-Key}
 * por {@link com.stellargear.royal_airlines.Config.InternalApiKeyFilter} y jamas con JWT
 * de usuario.
 *
 * <p>Dos direcciones posibles del contrato (el documento de reestructuracion las llama
 * opcion 1 y 2):</p>
 *
 * <ul>
 *   <li><b>Lectura:</b> {@code GET /internal/export/*} pagina las colecciones de entrenamiento
 *       con {@code since}, para que Python pueda leer sin tocar MongoDB.</li>
 *   <li><b>Escritura:</b> {@code POST /internal/recommendations/bulk} recibe las listas
 *       calculadas, para que Python no necesite permiso de escritura en la base.</li>
 * </ul>
 *
 * <p>Con la opcion 2 (lectura directa de Python, la que hoy usa {@code recommender}), los
 * exports quedan como via alternativa; el bulk si es la via limpia de escritura.</p>
 *
 * <p>Tambien agrupa utilidades de operacion (refrescos manuales y alta de vuelos de prueba),
 * que por estar bajo {@code /internal/**} nunca quedan al alcance de un usuario de la app.</p>
 */
@RestController
@RequiredArgsConstructor
@RequestMapping(path = "/internal")
public class InternalController {

    /** Exports admitidos: nombre de ruta -> coleccion y campo de fecha para {@code since}. */
    private static final Map<String, Export> EXPORTS = Map.of(
            "locations", new Export("Destinations", "updatedAt", false),
            "flights", new Export("Flights", "updatedAt", false),
            "bookings", new Export("Booking", "updatedAt", false),
            "events", new Export("UserEvents", "receivedAt", true));

    private static final int MAX_PAGE_SIZE = 500;

    private final MongoTemplate mongoTemplate;
    private final RecommendationService recommendationService;
    private final TrendingFeaturedService trendingFeaturedService;
    private final PromotionService promotionService;
    private final FlightService flightService;
    private final OfferNotificationService offerNotificationService;

    private record Export(String collection, String dateField, boolean instantField) {}

    /**
     * Pagina una coleccion de entrenamiento.
     *
     * @param name nombre del export: locations, flights, bookings o events.
     * @param since fecha minima del campo de actualizacion, ISO-8601 (opcional).
     * @param page indice de pagina, desde 0.
     * @param size tamanio de pagina, hasta 500.
     * @return documentos crudos con sus identificadores como cadena.
     */
    @GetMapping(path = "/export/{name}")
    public List<Map<String, Object>> export(@PathVariable String name,
                                            @RequestParam(required = false) String since,
                                            @RequestParam(defaultValue = "0") int page,
                                            @RequestParam(defaultValue = "100") int size) {
        Export export = EXPORTS.get(name);

        if (export == null) {
            throw new BadRequestException("Export desconocido: " + name + " (use locations, flights, bookings o events)");
        }

        int safeSize = Math.min(Math.max(size, 1), MAX_PAGE_SIZE);
        long skip = (long) Math.max(page, 0) * safeSize;

        Criteria criteria = new Criteria();

        if (since != null && !since.isBlank()) {
            criteria = criteria.and(export.dateField()).gte(parseSince(since, export.instantField()));
        }

        Query query = new Query(criteria)
                .with(Sort.by(Sort.Direction.ASC, "_id"))
                .skip(skip)
                .limit(safeSize);

        List<Map<String, Object>> result = new ArrayList<>();

        for (Document document : mongoTemplate.find(query, Document.class, export.collection())) {
            Map<String, Object> row = new LinkedHashMap<>(document);
            Object id = row.get("_id");

            if (id instanceof ObjectId objectId) {
                row.put("_id", objectId.toHexString());
            }
            result.add(row);
        }

        return result;
    }

    /**
     * Recibe el lote de listas calculadas por Python y lo guarda (reemplazando por usuario).
     *
     * @param documents documentos con {@code _id} y {@code items}, tal cual los escribe Python.
     * @return numero de listas guardadas.
     */
    @PostMapping(path = "/recommendations/bulk")
    @ResponseStatus(HttpStatus.CREATED)
    public Map<String, Object> bulk(@RequestBody List<UserRecommendationDocDTO> documents) {
        if (documents == null || documents.isEmpty()) {
            throw new BadRequestException("La lista de documentos esta vacia");
        }

        try {
            return Map.of("saved", recommendationService.saveBulk(documents));
        } catch (IllegalArgumentException invalid) {
            throw new BadRequestException(invalid.getMessage());
        }
    }

    /**
     * Refresca el featured dinamico con el trending de vistas de la ultima semana
     * (ver {@link TrendingFeaturedService}). Es la misma rutina del cron de las 03:45,
     * expuesta para poder probarla o correrla sin esperar al scheduler.
     *
     * @return resumen: cuantos destinos tienen tendencia, cuales quedaron featured y
     *         cuantos documentos cambiaron ({@code skipped=true} si no hubo señal y
     *         el catalogo se conservo tal cual).
     */
    @PostMapping(path = "/locations/refresh-featured")
    public Map<String, Object> refreshFeatured() {
        TrendingFeaturedService.RefreshResult result = trendingFeaturedService.refreshFeatured();
        return Map.of(
                "destinationsWithTrend", result.destinationsWithTrend(),
                "featured", result.featuredIds(),
                "modified", result.modified(),
                "skipped", result.skipped());
    }

    /**
     * Regenera las promociones del slider a partir de los vuelos proximos (ver
     * {@link PromotionService}). Es la misma rutina del cron de las 03:55 y de la
     * comprobacion de frescura al servir, expuesta para poder probarla o correrla
     * sin esperar al scheduler.
     *
     * @return resumen: cuantas rutas se evaluaron, cuantas promociones se publicaron,
     *         cuales se retiraron ({@code skipped=true} si no hubo vuelos utilizables y
     *         se conservo la coleccion tal cual).
     */
    @PostMapping(path = "/promotions/refresh")
    public Map<String, Object> refreshPromotions() {
        PromotionService.RefreshResult result = promotionService.refresh();
        return Map.of(
                "routesEvaluated", result.routesEvaluated(),
                "promotions", result.promotions(),
                "removed", result.removed(),
                "skipped", result.skipped());
    }

    /**
     * Dispara a mano el aviso push de una oferta (misma rutina que el evento y el job de
     * respaldo). Util para probar sin esperar. La deduplicacion sigue aplicando: para repetir
     * la prueba hay que borrar el documento de la coleccion OfferNotifications.
     *
     * @param flightId vuelo a evaluar.
     * @return resumen: si se proceso, cuantos candidatos, cuantos coincidieron y a cuantos se envio.
     */
    @PostMapping(path = "/offers/notify/{flightId}")
    public Map<String, Object> notifyOffer(@PathVariable String flightId) {
        OfferNotificationService.Summary summary =
                offerNotificationService.notifyOffer(flightService.searchFlightByID(flightId));
        return Map.of(
                "processed", summary.processed(),
                "candidates", summary.candidates(),
                "matched", summary.matched(),
                "sent", summary.sent());
    }

    /**
     * Crea un vuelo (o una oferta, si se indica descuento) para pruebas y operacion. Si es oferta,
     * dispara el aviso push igual que cualquier alta de oferta. Solo accesible con
     * {@code X-API-Key}: antes vivia en {@code /api/v1/flights/debug/create} y lo podia llamar
     * cualquier usuario autenticado.
     *
     * @param airline nombre de la companhia aerea.
     * @param price precio base del pasaje en dolares.
     * @param depID identificador del aeropuerto de salida.
     * @param arrID identificador del aeropuerto de llegada.
     * @param flightNum numero de vuelo.
     * @param discountPercentage descuento opcional (1-90): crea el vuelo como oferta y dispara el push.
     * @param offerValidDays vigencia de la oferta en dias (7 por defecto).
     * @param departureInDays dias hasta la salida (7 si es oferta, 0 si no).
     * @return identificador del vuelo creado.
     */
    @PostMapping(path = "/flights/create")
    @ResponseStatus(HttpStatus.CREATED)
    public String createFlight(@RequestParam @NotBlank String airline,
                               @RequestParam @Positive double price,
                               @RequestParam @NotBlank String depID,
                               @RequestParam @NotBlank String arrID,
                               @RequestParam @NotBlank String flightNum,
                               @RequestParam(required = false) @DecimalMin("1") @DecimalMax("90") Double discountPercentage,
                               @RequestParam(required = false) @Min(1) Integer offerValidDays,
                               @RequestParam(required = false) @Min(0) Integer departureInDays) {
        return flightService.addNewFlight(airline, price, depID, arrID, flightNum,
                discountPercentage, offerValidDays, departureInDays);
    }

    private Object parseSince(String value, boolean instantField) {
        try {
            return instantField ? Instant.parse(value) : LocalDateTime.parse(value);
        } catch (RuntimeException malformed) {
            throw new BadRequestException("since debe ser ISO-8601, por ejemplo 2026-10-28T03:00:00");
        }
    }
}
