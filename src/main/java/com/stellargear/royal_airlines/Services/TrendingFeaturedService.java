package com.stellargear.royal_airlines.Services;

import com.stellargear.royal_airlines.Models.Entities.Location;
import com.stellargear.royal_airlines.Models.Enums.LocationStatus;
import com.stellargear.royal_airlines.Repositories.LocationRepository;
import java.time.Duration;
import java.time.Instant;
import java.util.Comparator;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.bson.Document;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.mongodb.core.BulkOperations;
import org.springframework.data.mongodb.core.BulkOperations.BulkMode;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.aggregation.Aggregation;
import org.springframework.data.mongodb.core.aggregation.ArrayOperators;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

/**
 * Featured DINAMICO a partir del trending de vistas.
 *
 * <p>Historicamente {@code Location.featured} lo fijaba a mano el admin. Aqui pasa a computarse:
 * cada madrugada (o bajo demanda via {@code POST /internal/locations/refresh-featured}) se
 * agregan los eventos {@code destination_view} de los ultimos 7 dias contando USUARIOS UNICOS por
 * destino, y el top-N que supere el minimo de muestra queda {@code featured=true} (el resto de los
 * ACTIVE pasa a {@code false}). Cambiar este UN campo actualiza de inmediato a los tres consumidores
 * que ya existen:</p>
 *
 * <ul>
 *   <li>Home del front ({@code GET /locations/?featured=true} = "Destinos populares");</li>
 *   <li>el fallback de Java en RecommendationService (0.05 * featured + razon FEATURED);</li>
 *   <li>el fallback de Python (scoring.py, mismo peso 0.05).</li>
 * </ul>
 *
 * <p>Guardrails: usuarios unicos (no vistas crudas) para que un solo curioso no secuestre el
 * ranking; minimo de muestra (ruido con pocos usuarios); solo destinos ACTIVE; y si NADA supera
 * el minimo (semana seca o sin consentimientos) NO se escribe nada, para no vaciar "Destinos
 * populares". La toma de decision es {@link #selectFeatured}, pura y testeable sin MongoDB.</p>
 */
@Service
@RequiredArgsConstructor
public class TrendingFeaturedService {

  private static final Logger logger = LoggerFactory.getLogger(TrendingFeaturedService.class);

  /** Tipo de evento de cliente que cuenta como vista de destino (UserEventService.CLIENT_TYPES). */
  static final String VIEW_TYPE = "destination_view";

  /** Coleccion de eventos (UserEvent). */
  static final String EVENTS_COLLECTION = "UserEvents";

  /** Ventana del trending. */
  static final int WINDOW_DAYS = 7;

  /** Tamano del destacado. */
  static final int TOP_N = 5;

  /** Usuarios unicos minimos para que un destino entre al ranking (guardia de ruido). */
  static final int MIN_UNIQUE_VIEWERS = 3;

  private final LocationRepository locationRepository;
  private final MongoTemplate mongoTemplate;

  /** Usuarios unicos que miraron un destino dentro de la ventana. */
  record TrendingCount(String locationId, int uniqueUsers) {}

  /** Resultado del refresh, para logs y el endpoint manual. */
  public record RefreshResult(int destinationsWithTrend, List<String> featuredIds, int modified,
                              boolean skipped) {}

  /**
   * Refresco programado. Cron configurable con {@code royal.trending.refresh-cron}
   * (por defecto 03:45 de Bogota, despues del snapshot de precios de las 03:30).
   * {@code EnableScheduling} ya esta activo en la aplicacion.
   *
   * @return resumen del refresco.
   */
  @Scheduled(cron = "${royal.trending.refresh-cron:0 45 3 * * *}", zone = "America/Bogota")
  public RefreshResult refreshFeatured() {
    RefreshResult result = refresh();
    if (result.skipped()) {
      logger.info("TrendingFeatured: sin señal suficiente ({} destinos con tendencia); featured conservado",
          result.destinationsWithTrend());
    } else {
      logger.info("TrendingFeatured: {} destinos con tendencia -> featured = {} ({} documentos modificados)",
          result.destinationsWithTrend(), result.featuredIds(), result.modified());
    }
    return result;
  }

  /**
   * Nucleo del refresh, separado de {@code @Scheduled} para poder llamarlo desde
   * {@code InternalController}.
   *
   * @return resumen del refresco.
   */
  RefreshResult refresh() {
    List<TrendingCount> counts = trendingCounts(Instant.now().minus(Duration.ofDays(WINDOW_DAYS)));
    List<Location> actives = locationRepository.findByStatus(LocationStatus.ACTIVE);

    Set<String> featured = selectFeatured(counts, actives);
    if (featured.isEmpty()) {
      // Sin eventos (o sin ninguno que supere el minimo): NO se toca el catalogo.
      return new RefreshResult(counts.size(), List.of(), 0, true);
    }

    List<String> activeIds = actives.stream()
        .map(Location::getLocationID)
        .filter(Objects::nonNull)
        .toList();
    List<String> toDemote = activeIds.stream().filter(id -> !featured.contains(id)).toList();

    BulkOperations bulk = mongoTemplate.bulkOps(BulkMode.UNORDERED, Location.class);
    bulk.updateMulti(Query.query(Criteria.where("locationID").in(featured)),
        new Update().set("featured", true));
    if (!toDemote.isEmpty()) {
      bulk.updateMulti(Query.query(Criteria.where("locationID").in(toDemote)),
          new Update().set("featured", false));
    }
    int modified = bulk.execute().getModifiedCount();

    return new RefreshResult(counts.size(), List.copyOf(featured), modified, false);
  }

  /**
   * Usuarios unicos por destino en la ventana, via agregacion de MongoDB apoyada en el indice
   * (type, ts, destinationId) de la coleccion UserEvents. {@code addToSet(userId)} es lo que
   * convierte "vistas" en "usuarios distintos que lo miraron".
   *
   * @param since inicio de la ventana de tiempo.
   * @return usuarios unicos por destino dentro de la ventana.
   */
  List<TrendingCount> trendingCounts(Instant since) {
    Aggregation aggregation = Aggregation.newAggregation(
        Aggregation.match(Criteria.where("type").is(VIEW_TYPE)
            .and("ts").gte(since)
            .and("destinationId").exists(true)
            .ne("")),
        Aggregation.group("destinationId").addToSet("userId").as("viewers"),
        Aggregation.project()
            .and(ArrayOperators.arrayOf("viewers").length()).as("uniqueUsers"));

    List<Document> rows = mongoTemplate
        .aggregate(aggregation, EVENTS_COLLECTION, Document.class)
        .getMappedResults();

    return rows.stream()
        .map(row -> new TrendingCount(row.getString("_id"), asInt(row.get("uniqueUsers"))))
        .filter(count -> count.locationId() != null)
        .toList();
  }

  /**
   * Decide que destinos quedan destacados: solo ACTIVE, con al menos
   * {@value #MIN_UNIQUE_VIEWERS} usuarios unicos, ordenados de mayor a menor (con desempate
   * estable por id) y cortados a los {@value #TOP_N} primeros. Puro: sin MongoDB ni estado.
   *
   * @param counts usuarios unicos por destino.
   * @param actives destinos activos del catalogo.
   * @return identificadores de los destinos que deben quedar destacados.
   */
  static Set<String> selectFeatured(List<TrendingCount> counts, List<Location> actives) {
    Set<String> activeIds = actives.stream()
        .map(Location::getLocationID)
        .filter(Objects::nonNull)
        .collect(Collectors.toSet());

    return counts.stream()
        .filter(count -> count.locationId() != null)
        .filter(count -> count.uniqueUsers() >= MIN_UNIQUE_VIEWERS)
        .filter(count -> activeIds.contains(count.locationId()))
        .sorted(Comparator.comparingInt(TrendingCount::uniqueUsers).reversed()
            .thenComparing(TrendingCount::locationId))
        .limit(TOP_N)
        .map(TrendingCount::locationId)
        .collect(Collectors.toCollection(LinkedHashSet::new));
  }

  private static int asInt(Object value) {
    return value instanceof Number number ? number.intValue() : 0;
  }
}
