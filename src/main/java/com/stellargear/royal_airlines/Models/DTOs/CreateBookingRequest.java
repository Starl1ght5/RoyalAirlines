package com.stellargear.royal_airlines.Models.DTOs;

import com.stellargear.royal_airlines.Models.Entities.Booking;
import com.stellargear.royal_airlines.Models.Enums.CompanionType;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import java.util.List;

/**
 * Datos necesarios para crear una reserva.
 *
 * <p>El usuario no viaja en el cuerpo de la peticion: se obtiene siempre del token JWT.</p>
 *
 * <p>Los campos desde {@code tripType} en adelante son opcionales y alimentan el historial que
 * usa el servicio de recomendaciones.</p>
 *
 * @param flightID identificador del vuelo.
 * @param feeID identificador de la tarifa seleccionada.
 * @param seats codigos de los asientos elegidos, con un maximo de nueve.
 * @param tripType tipo de viaje; {@code null} se interpreta como solo ida.
 * @param stayDays dias de estadia entre ida y regreso.
 * @param companionType chip de un toque en el checkout; la senal mas valiosa para el recomendador.
 * @param passengerAges edades de los pasajeros, una por asiento.
 * @param extras extras contratados por el usuario.
 * @param source pantalla desde la que se origino la reserva.
 * @param recommendationID recomendacion que origino la reserva, si aplica.
 */
public record CreateBookingRequest(
        @NotBlank(message = "El vuelo es obligatorio")
        String flightID,

        @NotBlank(message = "La tarifa es obligatoria")
        String feeID,

        @NotEmpty(message = "Debes elegir al menos un asiento")
        @Size(max = 9, message = "Maximo 9 asientos por reserva")
        List<@NotBlank(message = "Asiento vacio")
             @Pattern(regexp = "^\\d{1,2}[A-Fa-f]$", message = "Asiento invalido") String> seats,

        Booking.TripType tripType,

        @Min(0) @Max(365)
        Integer stayDays,

        CompanionType companionType,

        @Size(max = 9)
        List<@NotNull @Min(0) @Max(120) Integer> passengerAges,

        @Size(max = 20)
        List<@NotBlank @Size(max = 40) String> extras,

        Booking.BookingSource source,

        @Size(max = 64)
        String recommendationID
) {}