package com.stellargear.royal_airlines.Models.Validation;

import jakarta.validation.Constraint;
import jakarta.validation.Payload;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.lang.annotation.Documented;
import java.lang.annotation.Retention;
import java.lang.annotation.Target;

import static java.lang.annotation.ElementType.ANNOTATION_TYPE;
import static java.lang.annotation.ElementType.CONSTRUCTOR;
import static java.lang.annotation.ElementType.FIELD;
import static java.lang.annotation.ElementType.METHOD;
import static java.lang.annotation.ElementType.PARAMETER;
import static java.lang.annotation.ElementType.TYPE_USE;
import static java.lang.annotation.RetentionPolicy.RUNTIME;

/**
 * Regla unica para un correo recibido del cliente: obligatorio, con formato valido y de a lo
 * sumo 254 caracteres (el maximo de una direccion SMTP).
 *
 * <p>Cada regla compuesta informa su propio mensaje, de modo que las respuestas de error son
 * las mismas que con las tres anotaciones escritas por separado.</p>
 */
@NotBlank(message = "El email es obligatorio")
@Email(message = "El email no es valido")
@Size(max = 254, message = "El email es demasiado largo")
@Documented
@Constraint(validatedBy = {})
@Target({METHOD, FIELD, ANNOTATION_TYPE, CONSTRUCTOR, PARAMETER, TYPE_USE})
@Retention(RUNTIME)
public @interface ValidEmail {

    String message() default "El email no es valido";

    Class<?>[] groups() default {};

    Class<? extends Payload>[] payload() default {};
}
