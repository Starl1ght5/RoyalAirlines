package com.stellargear.royal_airlines.Models.DTOs;

import java.time.LocalDateTime;
import java.util.List;

/**
 * Respuesta de {@code GET /api/v1/recommendations}: la lista del usuario, o en su defecto la
 * de {@code __popular__}, o un respaldo calculado al vuelo si el job nunca corrio.
 *
 * @param strategy estrategia que genero la lista (content | preferences | popular | fallback).
 * @param modelVersion version del modelo, o {@code fallback-v1} cuando no hay job.
 * @param recommendationID identificador de la lista; el front lo reenvia como {@code source}
 *                         {@code RECOMMENDATION} al reservar para atribuir la conversion.
 * @param generatedAt momento en que se calculo la lista.
 * @param items destinos recomendados, ordenados por puntaje.
 */
public record RecommendationListDTO(
        String strategy,
        String modelVersion,
        String recommendationID,
        LocalDateTime generatedAt,
        List<RecommendationItem> items
) {}
