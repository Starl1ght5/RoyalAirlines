package com.stellargear.royal_airlines.Models.Enums;

/**
 * Estados posibles de una reserva.
 */
public enum BookingStatus {
    /** Reserva creada con asientos retenidos y a la espera de confirmacion. */
    PENDING,
    /** Reserva confirmada, con su pase de aboardar emitido. */
    CONFIRMED,
    /** Reserva cancelada, con sus asientos liberados. */
    CANCELED
}