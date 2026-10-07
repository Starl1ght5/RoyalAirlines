package com.stellargear.royal_airlines.Utils;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.context.request.WebRequest;
import org.springframework.web.servlet.mvc.method.annotation.ResponseEntityExceptionHandler;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Convierte cualquier error en una respuesta {@code ProblemDetail} (RFC 9457).
 *
 * <p>Al extender {@code ResponseEntityExceptionHandler}, Spring ya transforma en
 * {@code ProblemDetail} los errores propios de MVC y las {@code ResponseStatusException}; esta
 * clase cubre los casos propios del dominio.</p>
 */
@RestControllerAdvice
public class GlobalExceptionHandler extends ResponseEntityExceptionHandler {

    private static final Logger logger = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    /**
     * Detalla los campos que fallaron al validar el cuerpo de la peticion.
     *
     * @param ex excepcion lanzada por la validacion del modelo.
     * @param headers cabeceras de la respuesta original.
     * @param status codigo de estado original.
     * @param request peticion que se esta procesando.
     * @return respuesta 400 con la propiedad {@code errors}.
     */
    @Override
    protected ResponseEntity<Object> handleMethodArgumentNotValid(MethodArgumentNotValidException ex,
                                                                   HttpHeaders headers,
                                                                   HttpStatusCode status,
                                                                   WebRequest request) {
        Map<String, String> errors = new LinkedHashMap<>();
        ex.getBindingResult().getFieldErrors()
                .forEach(error -> errors.putIfAbsent(error.getField(), error.getDefaultMessage()));

        ProblemDetail problem = ProblemDetail.forStatusAndDetail(HttpStatus.BAD_REQUEST, "Hay campos invalidos");
        problem.setTitle("Validacion fallida");
        problem.setProperty("errors", errors);

        return handleExceptionInternal(ex, problem, headers, HttpStatus.BAD_REQUEST, request);
    }

    /**
     * Responde 401 cuando las credenciales no son correctas.
     *
     * @param ex excepcion de autenticacion, normalmente por contrasena incorrecta.
     * @return detalle del problema con codigo 401.
     */
    @ExceptionHandler(AuthenticationException.class)
    public ProblemDetail handleAuthentication(AuthenticationException ex) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(HttpStatus.UNAUTHORIZED, "Credenciales invalidas");
        problem.setTitle("No autenticado");
        return problem;
    }

    /**
     * Responde 403 cuando el usuario esta autenticado pero sin permisos.
     *
     * @param ex excepcion de acceso denegado.
     * @return detalle del problema con codigo 403.
     */
    @ExceptionHandler(AccessDeniedException.class)
    public ProblemDetail handleAccessDenied(AccessDeniedException ex) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(HttpStatus.FORBIDDEN, "No tienes permiso para esta accion");
        problem.setTitle("Acceso denegado");
        return problem;
    }

    /**
     * Responde 409 cuando se viola un indice unico, por ejemplo dos registros simultaneos con el
     * mismo correo.
     *
     * @param ex excepcion de clave duplicada de la base de datos.
     * @return detalle del problema con codigo 409.
     */
    @ExceptionHandler(DuplicateKeyException.class)
    public ProblemDetail handleDuplicateKey(DuplicateKeyException ex) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(HttpStatus.CONFLICT, "El registro ya existe");
        problem.setTitle("Conflicto");
        return problem;
    }

    /**
     * Ultima linea de defensa ante cualquier otro error.
     *
     * <p>El detalle se registra en el log, pero al cliente solo se le devuelve un mensaje generico
     * para no filtrar informacion interna.</p>
     *
     * @param ex excepcion no controlada.
     * @return detalle del problema con codigo 500.
     */
    @ExceptionHandler(Exception.class)
    public ProblemDetail handleUnexpected(Exception ex) {
        logger.error("Error no controlado: {}", ex.getMessage(), ex);

        ProblemDetail problem = ProblemDetail.forStatusAndDetail(HttpStatus.INTERNAL_SERVER_ERROR, "Error interno del servidor");
        problem.setTitle("Error interno");
        return problem;
    }
}