package com.stellargear.royal_airlines.Models.DTOs;

import com.stellargear.royal_airlines.Models.Validation.ValidEmail;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Datos editables del perfil de una cuenta.
 *
 * <p>Solo el nombre visible y el correo se cambian desde la app. El correo es unico por
 * cuenta, por lo que el servicio comprueba el conflicto antes de guardarlo.</p>
 *
 * @param fullName nombre visible que se muestra en la app.
 * @param email correo nuevo de la cuenta.
 */
public record UpdateProfileRequest(

        @NotBlank(message = "El nombre es obligatorio")
        @Size(max = 100, message = "El nombre es demasiado largo")
        String fullName,

        @ValidEmail
        String email
) {}
