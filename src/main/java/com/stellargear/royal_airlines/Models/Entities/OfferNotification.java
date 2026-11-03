package com.stellargear.royal_airlines.Models.Entities;

import java.time.Instant;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.CompoundIndex;
import org.springframework.data.mongodb.core.index.CompoundIndexes;
import org.springframework.data.mongodb.core.mapping.Document;

/**
 * Historial de avisos de oferta enviados. El indice unico (userId, flightId) es la
 * deduplicacion: un usuario nunca recibe dos veces el aviso del mismo vuelo. {@code score} se
 * guarda para poder ajustar el umbral de coincidencia con datos reales.
 */
@Document(collection = "OfferNotifications")
@CompoundIndexes({
  @CompoundIndex(name = "user_flight", def = "{'userId': 1, 'flightId': 1}", unique = true),
  @CompoundIndex(name = "user_sent", def = "{'userId': 1, 'sentAt': -1}")
})
public record OfferNotification(
    @Id String id,
    String userId,
    String flightId,
    double score,
    Instant sentAt,
    Status status) {

  /** SENT: llego a algun dispositivo. NO_DELIVERY: FCM no entrego a ninguno (tokens caidos). */
  public enum Status { SENT, NO_DELIVERY }
}
