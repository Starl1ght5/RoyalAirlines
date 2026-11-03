package com.stellargear.royal_airlines.Models.Entities;

import com.stellargear.royal_airlines.Models.DTOs.RecommendationItem;
import java.time.LocalDateTime;
import java.util.List;
import lombok.Getter;
import lombok.Setter;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

/**
 * Lista precalculada de recomendaciones para un usuario.
 *
 * <p>La escribe el microservicio Python (job nocturno) directamente o a traves de
 * {@code POST /internal/recommendations/bulk}; Spring solo lee. El documento con
 * {@code _id = "__popular__"} es el respaldo general para usuarios sin senal propia.</p>
 *
 * <p>Los nombres de campo son exactamente los del contrato con Python: si se renombran aqui,
 * hay que renombrarlos en {@code recommender/batch.py} a la vez.</p>
 */
@Getter
@Setter
@Document(collection = "UserRecommendations")
public class UserRecommendation {

    /** Identificador del usuario o {@code __popular__} para el ranking general. */
    @Id
    private String id;

    /** Estrategia que genero la lista: content | preferences | popular. */
    private String strategy;

    /** Version del modelo que produjo el resultado. */
    private String modelVersion;

    /** Identificador de la lista; se copia en {@code Booking.recommendationID} para medir conversion. */
    private String recommendationID;

    /** Momento en que el job calculo la lista. */
    private LocalDateTime generatedAt;

    /** Fecha de referencia con que se calculo (los perfiles dependen del tiempo). */
    private LocalDateTime asOf;

    /** Top de destinos recomendados, ordenado por puntaje. */
    private List<RecommendationItem> items;
}
