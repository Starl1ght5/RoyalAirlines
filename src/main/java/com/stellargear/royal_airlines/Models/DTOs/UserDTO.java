package com.stellargear.royal_airlines.Models.DTOs;

/**
 * Vista de un usuario lista para el cliente.
 *
 * @param userID identificador del usuario.
 * @param username nombre visible.
 * @param email correo registrado.
 * @param password nunca se expone el hash de la contrasena, por lo que viaja como nulo.
 * @param verified indica si el correo fue verificado.
 */
public record UserDTO(
        String userID,
        String username,
        String email,
        String password,
        boolean verified
) {}