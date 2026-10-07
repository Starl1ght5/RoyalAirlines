package com.stellargear.royal_airlines.Utils;

import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

/**
 * Error 409: el recurso ya existe o su estado actual no permite la operacion.
 */
public class ConflictException extends ResponseStatusException {

    /**
     * Crea el error de conflicto.
     *
     * @param message descripcion mostrada al cliente.
     */
    public ConflictException(String message) {
        super(HttpStatus.CONFLICT, message);
    }
}