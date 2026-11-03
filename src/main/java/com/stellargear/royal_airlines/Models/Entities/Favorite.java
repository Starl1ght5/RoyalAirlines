package com.stellargear.royal_airlines.Models.Entities;

import java.time.Instant;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.CompoundIndex;
import org.springframework.data.mongodb.core.index.CompoundIndexes;
import org.springframework.data.mongodb.core.mapping.Document;

/**
 * Un favorito por documento; el indice unico hace idempotente el {@code POST}.
 *
 * @param id identificador del documento.
 * @param userId propietario del favorito.
 * @param targetType tipo de elemento guardado.
 * @param targetId {@code Location.locationID} para destinos o {@code Flight.flightID} para vuelos.
 * @param createdAt momento en que se guardo el favorito.
 */
@Document(collection = "Favorites")
@CompoundIndexes({
  @CompoundIndex(name = "user_target", def = "{'userId': 1, 'targetType': 1, 'targetId': 1}", unique = true),
  @CompoundIndex(name = "user_created", def = "{'userId': 1, 'createdAt': -1}")
})
public record Favorite(
    @Id String id,
    String userId,
    TargetType targetType,
    String targetId,
    Instant createdAt) {

  public enum TargetType { DESTINATION, FLIGHT }
}
