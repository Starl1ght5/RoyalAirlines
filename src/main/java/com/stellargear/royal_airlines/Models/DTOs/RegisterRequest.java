package com.stellargear.royal_airlines.Models.DTOs;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Datos enviados para registrar un usuario.
 *
 * <p>La contrasena se limita a 72 caracteres porque BCrypt solo procesa los primeros 72 bytes;
 * sin ese limite, el exceso se descartaria en silencio.</p>
 *
 * @param email correo unico de la cuenta.
 * @param password contrasena de entre 8 y 72 caracteres.
 */
public record RegisterRequest(

        @NotBlank(message = "El email es obligatorio")
        @Email(message = "El email no es valido")
        @Size(max = 254, message = "El email es demasiado largo")
        String email,

        @NotBlank(message = "La contrasena es obligatoria")
        @Size(min = 8, max = 72, message = "La contrasena debe tener entre 8 y 72 caracteres")
        String password
) {}