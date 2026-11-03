package com.stellargear.royal_airlines.Models.DTOs;

/**
 * Respuesta simple para operaciones que no devuelven datos.
 *
 * @param success indica si la operacion se completo.
 * @param message mensaje listo para mostrar al usuario.
 */
public record MessageResponse(boolean success, String message) {}
