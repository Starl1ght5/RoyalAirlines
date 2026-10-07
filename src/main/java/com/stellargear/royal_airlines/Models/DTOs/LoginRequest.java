package com.stellargear.royal_airlines.Models.DTOs;

import jakarta.validation.constraints.NotBlank;

/**
 * Credenciales enviadas para iniciar sesion.
 *
 * @param email correo registrado.
 * @param password contrasena del usuario.
 */
public record LoginRequest(

        @NotBlank(message = "El email es obligatorio")
        String email,

        @NotBlank(message = "La contrasena es obligatoria")
        String password
) {}