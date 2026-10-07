package com.stellargear.royal_airlines.Models.Enums;

/**
 * Ciclo de vida de un pase de abordar.
 */
public enum BoardingPassStatus {
    /** Pase vigente para el vuelo. */
    ACTIVE,
    /** Pase ya inutilizado, por ejemplo porque su vuelo fue cancelado. */
    INACTIVE
}