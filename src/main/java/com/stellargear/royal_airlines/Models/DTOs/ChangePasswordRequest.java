package com.stellargear.royal_airlines.Models.DTOs;

import com.stellargear.royal_airlines.Models.Validation.ValidPassword;
import jakarta.validation.constraints.NotBlank;

/**
 * Datos para cambiar la contrasena de una cuenta autenticada.
 *
 * <p>Se exige la contrasena actual para que el token robado o una sesion abierta no baste para
 * apropiarse de la cuenta. El maximo de 72 caracteres viene de BCrypt, que ignora el resto en
 * silencio.</p>
 *
 * @param currentPassword contrasena que el usuario tiene ahora.
 * @param newPassword contrasena nueva, entre 8 y 72 caracteres.
 */
public record ChangePasswordRequest(

        @NotBlank(message = "La contrasena actual es obligatoria")
        String currentPassword,

        @NotBlank(message = "La contrasena nueva es obligatoria")
        @ValidPassword
        String newPassword
) {}
