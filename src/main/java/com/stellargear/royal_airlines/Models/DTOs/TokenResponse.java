package com.stellargear.royal_airlines.Models.DTOs;

/**
 * Respuesta del inicio de sesion.
 *
 * @param token JWT que el cliente debe enviar en la cabecera {@code Authorization}.
 */
public record TokenResponse(String token) {}