package com.stellargear.royal_airlines.Services;

import com.stellargear.royal_airlines.Models.DTOs.PricePointDTO;
import com.stellargear.royal_airlines.Models.Entities.Flight;
import com.stellargear.royal_airlines.Models.Entities.Location;
import com.stellargear.royal_airlines.Models.Entities.PriceSnapshot;
import com.stellargear.royal_airlines.Models.Enums.FlightStatus;
import com.stellargear.royal_airlines.Repositories.FlightRepository;
import com.stellargear.royal_airlines.Repositories.LocationRepository;
import com.stellargear.royal_airlines.Repositories.PriceSnapshotRepository;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.DoubleSummaryStatistics;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.mongodb.core.BulkOperations;
import org.springframework.data.mongodb.core.BulkOperations.BulkMode;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

/**
 * Captura el historial diario de precios y lo sirve al cliente.
 */
@Service
@RequiredArgsConstructor
public class PriceSnapshotService {

  private static final Logger logger = LoggerFactory.getLogger(PriceSnapshotService.class);
  private static final ZoneId ZONE = ZoneId.of("America/Bogota");
  private static final int SCHEMA_VERSION = 1;
  private static final int DAYS_AHEAD = 90;
  private static final int CHUNK = 1000;

  private final FlightRepository flightRepository;
  private final LocationRepository locationRepository;
  private final PriceSnapshotRepository snapshotRepository;
  private final MongoTemplate mongoTemplate;

  private record Key(String origin, String destination, String departure) {}

  /**
   * Foto diaria de los vuelos ACTIVE con salida en los proximos 90 dias, agrupada por
   * (origen, destino, fecha de salida). Upsert idempotente: correrlo dos veces el mismo dia
   * (o en dos instancias) actualiza el mismo documento. EnableScheduling ya esta activo.
   */
  @Scheduled(cron = "${royal.prices.snapshot-cron:0 30 3 * * *}", zone = "America/Bogota")
  public void captureUpcoming() {
    LocalDate today = LocalDate.now(ZONE);
    List<Flight> flights = flightRepository.findByStatusAndDepartureDateBetween(
        FlightStatus.ACTIVE, today.atStartOfDay(), today.plusDays(DAYS_AHEAD + 1L).atStartOfDay());

    Map<String, String> iataById = locationRepository.findAll().stream()
        .filter(l -> l.getIataCode() != null)
        .collect(Collectors.toMap(Location::getLocationID, Location::getIataCode, (a, b) -> a));

    Map<Key, List<Flight>> groups = flights.stream()
        .filter(f -> f.getDepartureDate() != null && f.getTicketPrice() > 0
            && iataById.containsKey(f.getDepartureLocationID())
            && iataById.containsKey(f.getArrivalLocationID()))
        .collect(Collectors.groupingBy(f -> new Key(
            iataById.get(f.getDepartureLocationID()),
            iataById.get(f.getArrivalLocationID()),
            f.getDepartureDate().toLocalDate().toString())));

    String capturedDate = today.toString();
    Instant now = Instant.now();
    List<Map.Entry<Key, List<Flight>>> entries = new ArrayList<>(groups.entrySet());

    for (int from = 0; from < entries.size(); from += CHUNK) {
      BulkOperations bulk = mongoTemplate.bulkOps(BulkMode.UNORDERED, PriceSnapshot.class);
      for (var entry : entries.subList(from, Math.min(from + CHUNK, entries.size()))) {
        Key k = entry.getKey();
        List<Flight> list = entry.getValue();
        DoubleSummaryStatistics prices = list.stream().mapToDouble(Flight::getTicketPrice).summaryStatistics();
        double maxDiscount = list.stream()
            .filter(Flight::isDiscounted).mapToDouble(Flight::getDiscountPercentage).max().orElse(0);

        Query query = Query.query(Criteria.where("routeKey").is(PriceSnapshot.routeKey(k.origin(), k.destination()))
            .and("departureDate").is(k.departure()).and("capturedDate").is(capturedDate));
        Update update = new Update()
            .set("originId", k.origin()).set("destinationId", k.destination())
            .set("capturedAt", now)
            .set("minPrice", prices.getMin()).set("avgPrice", prices.getAverage())
            .set("flightsCount", (int) prices.getCount()).set("maxDiscountPct", maxDiscount)
            .set("currency", "USD").set("source", "scheduled").set("schemaVersion", SCHEMA_VERSION);
        bulk.upsert(query, update);
      }
      bulk.execute();
    }
    logger.info("PriceSnapshots: {} vuelos leidos, {} snapshots escritos", flights.size(), entries.size());
  }

  /**
   * Devuelve el historial de precios de una ruta para una fecha de salida.
   *
   * @param origin codigo IATA del aeropuerto de salida.
   * @param destination codigo IATA del aeropuerto de llegada.
   * @param departureDate fecha de salida, en formato {@code yyyy-MM-dd}.
   * @param days ventana de dias hacia atras.
   * @return puntos de precio en orden cronologico.
   */
  public List<PricePointDTO> history(String origin, String destination, String departureDate, int days) {
    String from = LocalDate.now(ZONE).minusDays(days).toString();
    return snapshotRepository
        .findByRouteKeyAndDepartureDateAndCapturedDateGreaterThanEqualOrderByCapturedDateAsc(
            PriceSnapshot.routeKey(origin, destination), departureDate, from)
        .stream()
        .map(s -> new PricePointDTO(s.capturedDate(), s.minPrice(), s.flightsCount()))
        .toList();
  }
}
