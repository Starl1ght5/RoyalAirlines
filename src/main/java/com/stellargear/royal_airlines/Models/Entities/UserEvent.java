package com.stellargear.royal_airlines.Models.Entities;

import java.time.Instant;
import java.util.Map;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.CompoundIndex;
import org.springframework.data.mongodb.core.index.CompoundIndexes;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;

/**
 * Evento de comportamiento, append-only. Indices: (userId, ts) para exportar por usuario,
 * unico (userId, clientEventId) contra duplicados por reintentos, y TTL de 540 dias.
 *
 * <p>(type, ts, destinationId) sostiene el trending de vistas que decide
 * {@code Location.featured} (ver {@link com.stellargear.royal_airlines.Services.TrendingFeaturedService}).</p>
 *
 * <p>{@code destinationId} es {@code Location.locationID}; {@code flightId} es
 * {@code Flight.flightID}.</p>
 */
@Document(collection = "UserEvents")
@CompoundIndexes({
  @CompoundIndex(name = "user_ts", def = "{'userId': 1, 'ts': -1}"),
  @CompoundIndex(name = "user_clientEvent", def = "{'userId': 1, 'clientEventId': 1}", unique = true, sparse = true),
  @CompoundIndex(name = "type_ts_destination", def = "{'type': 1, 'ts': -1, 'destinationId': 1}")
})
public record UserEvent(
    @Id String id,
    String userId,
    String clientEventId,
    String type,
    @Indexed(name = "ttl_ts", expireAfterSeconds = 46_656_000) Instant ts,
    Instant receivedAt,
    String sessionId,
    String destinationId,
    String flightId,
    String bookingId,
    String recommendationId,
    Integer position,
    String context,
    Map<String, String> payload,
    int schemaVersion) {}
