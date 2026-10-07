package com.stellargear.royal_airlines.Models.Enums;

/**
 * Estados posibles de un vuelo.
 */
public enum FlightStatus {
    /** Vuelo disponible para la busqueda y la reserva. */
    ACTIVE,
    /** Vuelo cancelado, fuera del catalogo. */
    CANCELED
}