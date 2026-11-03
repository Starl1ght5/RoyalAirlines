package com.stellargear.royal_airlines.Models.DTOs;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.time.LocalDateTime;
import java.util.List;

/**
 * Documento de recomendacion tal como lo recibe {@code POST /internal/recommendations/bulk}.
 *
 * <p>Es el mismo shape que escribe Python en {@code UserRecommendations}: {@code _id} es el
 * identificador del usuario (o {@code __popular__}), y los datetimes llegan como ISO-8601.</p>
 *
 * @param id valor de {@code _id}: userID o {@code __popular__}.
 * @param strategy estrategia que genero la lista.
 * @param modelVersion version del modelo.
 * @param recommendationID identificador atribuible de la lista.
 * @param generatedAt momento del calculo.
 * @param asOf fecha de referencia del calculo.
 * @param items ranking de destinos.
 */
public record UserRecommendationDocDTO(
        @JsonProperty("_id") String id,
        String strategy,
        String modelVersion,
        String recommendationID,
        LocalDateTime generatedAt,
        LocalDateTime asOf,
        List<RecommendationItem> items
) {}
