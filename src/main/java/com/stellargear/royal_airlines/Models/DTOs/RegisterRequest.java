package com.stellargear.royal_airlines.Models.DTOs;

import com.stellargear.royal_airlines.Models.Validation.ValidEmail;
import com.stellargear.royal_airlines.Models.Validation.ValidPassword;
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
 * @param fullName nombre visible; opcional para no romper a los clientes que aun no lo envian.
 */
public record RegisterRequest(

        @ValidEmail
        String email,

        @NotBlank(message = "La contrasena es obligatoria")
        @ValidPassword
        String password,

        @Size(max = 100, message = "El nombre es demasiado largo")
        String fullName
) {}
