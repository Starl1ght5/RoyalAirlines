package com.stellargear.royal_airlines.Models.DTOs;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * Cuerpo del {@code PUT /users/me/devices}.
 *
 * @param token token FCM del dispositivo.
 * @param platform plataforma del dispositivo: {@code android} o {@code ios}.
 * @param appVersion version de la app, solo para diagnostico.
 */
public record DeviceRegisterRequest(
    @NotBlank @Size(max = 4096) String token,
    @NotBlank @Pattern(regexp = "android|ios", message = "platform debe ser android o ios") String platform,
    @Size(max = 32) String appVersion) {}
