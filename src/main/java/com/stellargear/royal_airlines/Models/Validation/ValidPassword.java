package com.stellargear.royal_airlines.Models.Validation;

import jakarta.validation.Constraint;
import jakarta.validation.Payload;
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
 * Longitud permitida para una contrasena nueva: entre 8 y 72 caracteres.
 *
 * <p>El maximo viene de BCrypt, que solo procesa los primeros 72 bytes; sin ese limite el
 * exceso se descartaria en silencio. No incluye {@code @NotBlank} a proposito: cada solicitud
 * conserva su propio mensaje de campo obligatorio ("La contrasena es obligatoria" al
 * registrarse, "La contrasena nueva es obligatoria" al cambiarla).</p>
 */
@Size(min = 8, max = 72, message = "La contrasena debe tener entre 8 y 72 caracteres")
@Documented
@Constraint(validatedBy = {})
@Target({METHOD, FIELD, ANNOTATION_TYPE, CONSTRUCTOR, PARAMETER, TYPE_USE})
@Retention(RUNTIME)
public @interface ValidPassword {

    String message() default "La contrasena debe tener entre 8 y 72 caracteres";

    Class<?>[] groups() default {};

    Class<? extends Payload>[] payload() default {};
}
