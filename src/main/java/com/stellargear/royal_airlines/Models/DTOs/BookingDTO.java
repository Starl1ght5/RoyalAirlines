package com.stellargear.royal_airlines.Models.DTOs;

import com.stellargear.royal_airlines.Models.Enums.BookingStatus;
import com.stellargear.royal_airlines.Models.Enums.CancelReason;
import com.stellargear.royal_airlines.Models.Enums.CompanionType;
import org.joda.money.Money;

import java.util.List;

/**
 * Vista completa de una reserva lista para el cliente.
 *
 * @param bookingID identificador de la reserva.
 * @param userID propietario de la reserva.
 * @param bookedFight datos del vuelo reservado.
 * @param selectedFee tarifa aplicada al vuelo.
 * @param totalPrice importe total de la reserva ya convertido a pesos colombianos.
 * @param status estado actual de la reserva.
 * @param ticketCount numero de pasajes comprados.
 * @param seats codigos de los asientos reservados, por ejemplo {@code 12B}.
 * @param flightID identificador del vuelo reservado.
 * @param feeID identificador de la tarifa seleccionada.
 * @param companionType compania con la que viaja; {@code null} si el usuario no lo indico.
 * @param cancelReason motivo de la cancelacion; {@code null} si la reserva no esta cancelada.
 * @param tripRating calificacion del viaje, de 1 a 5; {@code null} si aun no se califico.
 */
public record BookingDTO(
        String bookingID,
        String userID,
        FlightDTO bookedFight,
        FaresDTO selectedFee,
        Money totalPrice,
        BookingStatus status,
        int ticketCount,
        List<String> seats,
        String flightID,
        String feeID,
        CompanionType companionType,
        CancelReason cancelReason,
        Integer tripRating
) {}