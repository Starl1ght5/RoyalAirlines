package com.stellargear.royal_airlines.Models.DTOs;

import com.stellargear.royal_airlines.Models.Entities.Favorite.TargetType;
import jakarta.validation.constraints.*;

/**
 * Cuerpo del alta de un favorito.
 *
 * @param targetType tipo de elemento que se guarda: {@code DESTINATION} o {@code FLIGHT}.
 * @param targetId identificador del destino o del vuelo.
 */
public record FavoriteRequest(
    @NotNull TargetType targetType,
    @NotBlank @Size(max = 64) String targetId) {}
