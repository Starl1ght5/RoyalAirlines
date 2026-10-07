package com.stellargear.royal_airlines.Models.DTOs;

import org.joda.money.Money;

import java.time.LocalDateTime;
import java.util.List;

/**
 * Vista de un vuelo lista para el cliente.
 *
 * @param flightID identificador del vuelo.
 * @param airline compania aerea.
 * @param ticketPrice precio del pasaje ya convertido a pesos colombianos.
 * @param duration duracion del trayecto con formato {@code Xh Ym}.
 * @param flightNumber numero de vuelo.
 * @param departureLocation destino de salida.
 * @param arrivalLocation destino de llegada.
 * @param departureDate fecha y hora de salida.
 * @param arrivalDate fecha y hora de llegada.
 * @param availableSeats asientos disponibles, o nulo si no se 재산izado.
 * @param availableFees tarifas disponibles para el vuelo.
 */
public record FlightDTO(
        String flightID,
        String airline,
        Money ticketPrice,
        String duration,
        String flightNumber,
        LocationDTO departureLocation,
        LocationDTO arrivalLocation,
        LocalDateTime departureDate,
        LocalDateTime arrivalDate,
        List<SeatDTO> availableSeats,
        List<FeeDTO> availableFees
) {}