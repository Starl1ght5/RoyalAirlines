package com.stellargear.royal_airlines.Models.DTOs;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;

import java.util.List;

/**
 * Datos necesarios para crear una reserva.
 *
 * <p>El usuario no viaja en el cuerpo de la peticion: se obtiene siempre del token JWT.</p>
 *
 * @param flightID vuelo a reservar.
 * @param feeID tarifa elegida para el vuelo.
 * @param seatIDs asientos a reservar, con un maximo de nueve por reserva.
 */
public record CreateBookingRequest(

        @NotBlank(message = "El vuelo es obligatorio")
        String flightID,

        @NotBlank(message = "La tarifa es obligatoria")
        String feeID,

        @NotEmpty(message = "Debes elegir al menos un asiento")
        @Size(max = 9, message = "Maximo 9 asientos por reserva")
        List<@NotBlank(message = "Id de asiento vacio") String> seatIDs
) {}