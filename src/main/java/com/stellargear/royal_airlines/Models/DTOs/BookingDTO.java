package com.stellargear.royal_airlines.Models.DTOs;

import com.stellargear.royal_airlines.Models.Enums.BookingStatus;
import org.joda.money.Money;

import java.util.List;

/**
 * Vista completa de una reserva lista para el cliente.
 *
 * @param bookingID identificador de la reserva.
 * @param userID propietario de la reserva.
 * @param bookedFight datos del vuelo reservado.
 * @param bookedSeats asientos reservados.
 * @param selectedFee tarifa aplicada al vuelo.
 * @param totalPrice importe total de la reserva ya convertido a pesos colombianos.
 * @param status estado actual de la reserva.
 * @param ticketCount numero de pasajes comprados.
 * @param seatIDs identificadores de los asientos reservados.
 * @param flightID identificador del vuelo reservado.
 * @param feeID identificador de la tarifa seleccionada.
 */
public record BookingDTO(
        String bookingID,
        String userID,
        FlightDTO bookedFight,
        List<SeatDTO> bookedSeats,
        FeeDTO selectedFee,
        Money totalPrice,
        BookingStatus status,
        int ticketCount,
        List<String> seatIDs,
        String flightID,
        String feeID
) {}