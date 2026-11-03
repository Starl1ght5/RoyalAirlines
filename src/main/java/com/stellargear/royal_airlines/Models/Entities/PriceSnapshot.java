package com.stellargear.royal_airlines.Models.Entities;

import java.time.Instant;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.CompoundIndex;
import org.springframework.data.mongodb.core.index.CompoundIndexes;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;

/**
 * Foto diaria del precio de una ruta para una fecha de salida.
 *
 * <p>Grano: ({@code routeKey}, {@code departureDate}, {@code capturedDate}). Las fechas viajan
 * como texto ISO {@code yyyy-MM-dd} para evitar el desfase de un dia por zona horaria; el orden
 * del texto coincide con el orden cronologico. Los precios estan en USD, tal como se guardan en
 * {@code Flight.ticketPrice} (la conversion a COP la hace {@code MoneyExchange}).</p>
 */
@Document(collection = "PriceSnapshots")
@CompoundIndexes({
  @CompoundIndex(name = "route_dep_captured",
      def = "{'routeKey': 1, 'departureDate': 1, 'capturedDate': 1}", unique = true),
  @CompoundIndex(name = "route_captured", def = "{'routeKey': 1, 'capturedDate': -1}"),
  @CompoundIndex(name = "dest_captured", def = "{'destinationId': 1, 'capturedDate': -1}")
})
public record PriceSnapshot(
    @Id String id,
    String routeKey,          // "BOG-MDE" (IATA origen-destino)
    String originId,          // IATA
    String destinationId,     // IATA
    String departureDate,
    String capturedDate,
    @Indexed(name = "ttl_captured", expireAfterSeconds = 63_072_000) Instant capturedAt, // 730 dias
    double minPrice,
    double avgPrice,
    int flightsCount,
    double maxDiscountPct,
    String currency,          // "USD"
    String source,
    int schemaVersion) {

  public static String routeKey(String originIata, String destinationIata) {
    return (originIata + "-" + destinationIata).toUpperCase();
  }
}
