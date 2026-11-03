package com.stellargear.royal_airlines.Models.DTOs;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/**
 * Actualizacion del consentimiento del usuario.
 *
 * @param tracking permiso para registrar actividad y personalizar.
 * @param marketingOptIn permiso separado para ofertas por correo o notificaciones.
 * @param consentVersion version de la politica aceptada; opcional.
 */
public record ConsentRequest(
        @NotNull Boolean tracking,
        Boolean marketingOptIn,
        @Size(max = 20) String consentVersion
) {}
