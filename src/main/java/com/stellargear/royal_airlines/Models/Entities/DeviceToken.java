package com.stellargear.royal_airlines.Models.Entities;

import java.time.Instant;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;

/**
 * Token FCM de un dispositivo del usuario. Un usuario puede tener varios (telefono y tablet) y
 * un mismo token solo pertenece a un usuario a la vez: si alguien inicia sesion en un telefono
 * que antes usaba otra cuenta, el token se mueve al usuario nuevo.
 *
 * @param id identificador del documento.
 * @param userId propietario actual del token.
 * @param token token FCM del dispositivo.
 * @param platform plataforma del dispositivo: {@code android} o {@code ios}.
 * @param appVersion version de la app, solo para diagnostico.
 * @param createdAt momento en que se registro el token.
 * @param lastSeenAt ultimo momento en que el dispositivo renovo el token.
 */
@Document(collection = "DeviceTokens")
public record DeviceToken(
    @Id String id,
    @Indexed String userId,
    @Indexed(unique = true) String token,
    String platform,
    String appVersion,
    Instant createdAt,
    Instant lastSeenAt) {}
