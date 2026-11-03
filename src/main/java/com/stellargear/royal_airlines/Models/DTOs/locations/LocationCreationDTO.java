package com.stellargear.royal_airlines.Models.DTOs.locations;

import com.stellargear.royal_airlines.Models.Enums.ClimateType;
import com.stellargear.royal_airlines.Models.Enums.VisaPolicy;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;

import java.util.List;
import java.util.Map;

/**
 * Datos para registrar un destino nuevo.
 *
 * @param cityName ciudad del destino.
 * @param countryName pais del destino.
 * @param iataCode codigo IATA del aeropuerto, de tres letras.
 * @param airportName nombre del aeropuerto.
 * @param tags etiquetas turisticas con peso de 0.0 a 1.0.
 * @param travelerFit encaje con cada tipo de viajero, con peso de 0.0 a 1.0.
 * @param bestMonths meses recomendados, del 1 al 12.
 * @param climateType clima normalizado del destino.
 * @param costLevel nivel de costo de vida, de 1 a 4.
 * @param visaPolicy requisitos de visa para pasaporte colombiano.
 * @param entryNote aviso al usuario sobre el control de entrada.
 * @param ratingCount numero de calificaciones recibidas.
 * @param imageUrl imagen del destino para las tarjetas del front.
 */
public record LocationCreationDTO(
        @NotBlank String cityName,
        @NotBlank String countryName,
        @NotBlank @Size(min = 3, max = 3) String iataCode,
        @NotBlank String airportName,
        @NotEmpty Map<@NotBlank String, @NotNull @DecimalMin("0.0") @DecimalMax("1.0") Double> tags,
        Map<@NotBlank String, @NotNull @DecimalMin("0.0") @DecimalMax("1.0") Double> travelerFit,
        @NotEmpty List<@NotNull @Min(1) @Max(12) Integer> bestMonths,
        @NotNull ClimateType climateType,
        @Min(1) @Max(4) int costLevel,
        @NotNull VisaPolicy visaPolicy,
        @Size(max = 300) String entryNote,
        @PositiveOrZero int ratingCount,
        @Size(max = 500) String imageUrl
) {}
