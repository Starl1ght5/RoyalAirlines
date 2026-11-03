package com.stellargear.royal_airlines.Models.DTOs;

import com.stellargear.royal_airlines.Models.Validation.ValidEmail;

/**
 * Solicitud de recuperacion de contrasena.
 *
 * <p>El correo se valida como cualquier otro, pero el servicio responde igual exista o no la
 * cuenta: asi nadie puede usar este endpoint para descubrir que correos estan registrados.</p>
 *
 * @param email correo al que se enviarian las instrucciones.
 */
public record ForgotPasswordRequest(

        @ValidEmail
        String email
) {}
