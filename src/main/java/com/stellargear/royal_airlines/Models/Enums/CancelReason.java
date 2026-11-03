package com.stellargear.royal_airlines.Models.Enums;

/**
 * Motivo de cancelacion de una reserva.
 *
 * <p>Distingue la decision del usuario de la expiracion automatica: para el recomendador
 * son senales opuestas y no deben contarse juntas.</p>
 */
public enum CancelReason {
    /** Cancelada por el usuario. */
    USER,
    /** Expirada por la tarea programada tras el tiempo de retencion. */
    EXPIRED,
    /** Cancelada por el sistema por un error interno. */
    SYSTEM
}
