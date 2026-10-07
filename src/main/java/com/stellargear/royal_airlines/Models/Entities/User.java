package com.stellargear.royal_airlines.Models.Entities;

import lombok.Getter;
import lombok.Setter;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;

import java.util.UUID;

/**
 * Cuenta de usuario de la aplicacion.
 *
 * <p>Una cuenta puede crearse con contrasena, con Google, o con ambos metodos. El campo
 * {@code googleSub} solo se llena cuando el usuario entra con Google y es unico cuando existe,
 * de modo que el indice no restringe a las cuentas locales.</p>
 */
@Getter
@Setter
@Document(collection = "Users")
public class User {

    @Id
    private String userID;

    private String username;

    @Indexed(unique = true)
    private String email;

    private String password;

    @Indexed(unique = true, sparse = true)
    private String googleSub;

    private boolean verified;
    private String verificationCode;

    /**
     * Crea la cuenta sin verificar y con un codigo de verificacion aleatorio.
     *
     * <p>El codigo se genera aqui para que exista incluso si el registro se guarda antes de que
     * el servicio termine de configurar los demas campos.</p>
     */
    public User() {
        this.verified = false;
        this.verificationCode = UUID.randomUUID().toString();
    }
}