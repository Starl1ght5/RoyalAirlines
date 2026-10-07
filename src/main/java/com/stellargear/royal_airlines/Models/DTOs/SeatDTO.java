package com.stellargear.royal_airlines.Models.DTOs;

import org.joda.money.Money;

/**
 * Vista de un asiento lista para el cliente.
 *
 * @param seatID identificador del asiento.
 * @param seatNumber numero visible del asiento, por ejemplo {@code A12}.
 * @param seatPrice precio del asiento ya convertido a pesos colombianos.
 * @param reserved indica si el asiento esta ocupado o retenido por una reserva.
 */
public record SeatDTO(
        String seatID,
        String seatNumber,
        Money seatPrice,
        boolean reserved
) {}