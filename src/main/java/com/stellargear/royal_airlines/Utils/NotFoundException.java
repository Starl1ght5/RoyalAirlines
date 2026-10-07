package com.stellargear.royal_airlines.Utils;

import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

/**
 * Error 404: el recurso solicitado no existe.
 *
 * <p>{@code GlobalExceptionHandler} lo convierte en una respuesta {@code ProblemDetail}.</p>
 */
public class NotFoundException extends ResponseStatusException {

    /**
     * Crea el error de recurso inexistente.
     *
     * @param message descripcion mostrada al cliente.
     */
    public NotFoundException(String message) {
        super(HttpStatus.NOT_FOUND, message);
    }
}