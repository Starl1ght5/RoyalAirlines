package com.stellargear.royal_airlines.Models.DTOs;

import com.fasterxml.jackson.annotation.JsonInclude;

/**
 * Perfil de la cuenta tal como lo consume la app.
 *
 * <p>Los nombres de campo ({@code id}, {@code fullName}) son los que lee el frontend.</p>
 *
 * @param id identificador del usuario.
 * @param fullName nombre visible de la cuenta (vacio si el registro es antiguo).
 * @param email correo registrado.
 * @param avatarUrl URL de la foto de perfil; el backend aun no la almacena, asi que se omite.
 * @param token JWT recien emitido; solo lo trae la respuesta de actualizacion. El JWT usa el
 *        correo como sujeto, de modo que al cambiarlo hay que entregar uno nuevo para que la
 *        sesion siga viva.
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public record UserProfileDTO(
        String id,
        String fullName,
        String email,
        String avatarUrl,
        String token
) {}
