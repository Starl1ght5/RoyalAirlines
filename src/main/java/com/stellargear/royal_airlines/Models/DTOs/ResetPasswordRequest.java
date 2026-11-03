package com.stellargear.royal_airlines.Models.DTOs;

import com.stellargear.royal_airlines.Models.Validation.ValidEmail;
import com.stellargear.royal_airlines.Models.Validation.ValidPassword;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

/**
 * Datos para restablecer la contrasena con el codigo enviado por correo.
 *
 * <p>El correo identifica la cuenta y el codigo demuestra que quien pide el cambio controla ese
 * buzon. El codigo viaja como seis digitos y caduca a los 30 minutos.</p>
 *
 * @param email correo de la cuenta.
 * @param code codigo de seis digitos recibido en el correo.
 * @param newPassword contrasena nueva, entre 8 y 72 caracteres.
 */
public record ResetPasswordRequest(

        @ValidEmail
        String email,

        @NotBlank(message = "El codigo es obligatorio")
        @Pattern(regexp = "\\d{6}", message = "El codigo debe tener seis digitos")
        String code,

        @NotBlank(message = "La contrasena nueva es obligatoria")
        @ValidPassword
        String newPassword
) {}
