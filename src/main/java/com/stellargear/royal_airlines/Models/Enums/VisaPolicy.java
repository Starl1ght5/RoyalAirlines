package com.stellargear.royal_airlines.Models.Enums;

/**
 * Requisitos de visa de un destino para pasaporte colombiano.
 *
 * <p>Vocabulario controlado que comparte el backend con el servicio de recomendaciones:
 * los valores viajan como cadenas exactas.</p>
 */
public enum VisaPolicy {
    /** Destino domestico; no aplica control de visa. */
    NOT_APPLICABLE,
    /** Entrada sin visa (turismo corto). */
    NOT_REQUIRED,
    /** Autorizacion electronica de viaje, por ejemplo ETIAS. */
    ELECTRONIC_AUTH,
    /** Visa obligatoria antes de viajar. */
    VISA_REQUIRED
}
