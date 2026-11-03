package com.stellargear.royal_airlines.Models.DTOs;

import java.util.List;
import java.util.Map;

/**
 * Un destino recomendado con su puntaje y su explicacion.
 *
 * <p>Es el mismo tipo en los tres sitios donde viaja: el documento que escribe Python
 * ({@code UserRecommendationDocDTO}), la coleccion {@code UserRecommendations} y la respuesta
 * al cliente ({@code RecommendationListDTO}). Los nombres de campo son los del contrato con
 * Python: si se renombran aqui, hay que renombrarlos en {@code recommender/batch.py} a la vez.</p>
 *
 * @param locationID identificador del destino ({@code Location.locationID}).
 * @param iataCode codigo IATA, para enlazar sin buscar por id.
 * @param cityName ciudad para mostrar en la tarjeta.
 * @param score puntaje de 0 a 1.
 * @param components desglose del puntaje por componente (affinity, budget, season, offer, fit).
 * @param matchedTags etiquetas del destino que coinciden con el perfil.
 * @param reasons etiquetas cortas de por que aparece, como {@code TAG_MATCH} o {@code IN_SEASON}.
 */
public record RecommendationItem(
        String locationID,
        String iataCode,
        String cityName,
        double score,
        Map<String, Double> components,
        List<String> matchedTags,
        List<String> reasons
) {}
