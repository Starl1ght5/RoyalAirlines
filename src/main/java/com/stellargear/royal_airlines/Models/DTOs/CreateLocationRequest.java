package com.stellargear.royal_airlines.Models.DTOs;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

/**
 * Datos necesarios para registrar un destino.
 *
 * @param cityName ciudad del aeropuerto.
 * @param countryName pais del aeropuerto.
 * @param iataCode codigo IATA de tres letras mayusculas.
 * @param airportName nombre del aeropuerto.
 */
public record CreateLocationRequest(

        @NotBlank(message = "La ciudad es obligatoria")
        String cityName,

        @NotBlank(message = "El pais es obligatorio")
        String countryName,

        @NotBlank(message = "El codigo IATA es obligatorio")
        @Pattern(regexp = "[A-Z]{3}", message = "El codigo IATA son 3 letras mayusculas")
        String iataCode,

        @NotBlank(message = "El aeropuerto es obligatorio")
        String airportName
) {}