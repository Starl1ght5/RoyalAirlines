package com.stellargear.royal_airlines.Models.Enums;

/**
 * Estados posibles de una reserva.
 */
public enum BookingStatus {
    /** Reserva creada con asientos retenidos y a la espera de confirmacion. */
    PENDING,
    /** Reserva confirmada por el usuario; los asientos siguen ocupados. */
    CONFIRMED,
    /** Reserva cancelada, con sus asientos liberados y su motivo en {@code cancelReason}. */
    CANCELED
}