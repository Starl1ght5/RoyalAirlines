package com.stellargear.royal_airlines.Utils;

import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

/**
 * Error 400: la peticion es invalida (dato incorrecto o regla de negocio que no se cumple).
 *
 * <p>{@code GlobalExceptionHandler} lo convierte en una respuesta {@code ProblemDetail}.</p>
 */
public class BadRequestException extends ResponseStatusException {

    /**
     * Crea el error de peticion invalida.
     *
     * @param message descripcion mostrada al cliente.
     */
    public BadRequestException(String message) {
        super(HttpStatus.BAD_REQUEST, message);
    }
}
