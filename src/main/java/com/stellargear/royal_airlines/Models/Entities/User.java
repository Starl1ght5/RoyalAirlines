package com.stellargear.royal_airlines.Models.Entities;

import lombok.Getter;
import lombok.Setter;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

/**
 * Cuenta de usuario de la aplicacion.
 *
 * <p>Una cuenta puede crearse con contrasena, con Google, o con ambos metodos. El campo
 * {@code googleSub} solo se llena cuando el usuario entra con Google y es unico cuando existe,
 * de modo que el indice no restringe a las cuentas locales.</p>
 *
 * <p>Las preferencias de viaje no viven aqui: se guardan en su propia coleccion para mantener
 * esta entidad liviana.</p>
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
     * Codigo temporal para restablecer la contrasena. Se genera en
     * {@code POST /auth/forgot-password} y caduca a los 30 minutos. El envio del correo esta
     * simulado: el codigo se escribe en el log del servidor.
     */
    private String passwordResetCode;

    /** Momento en que vence {@link #passwordResetCode}; {@code null} si no hay solicitud activa. */
    private LocalDateTime passwordResetExpiresAt;

    /** Ano de nacimiento, opcional; reemplaza a la edad que antes se copiaba en cada reserva. */
    private Integer birthYear;

    /** Aeropuerto desde el que el usuario suele viajar; sirve como origen por defecto. */
    private String homeAirportID;

    /** Fecha de creacion de la cuenta; la asigna el servicio al registrar. */
    private LocalDateTime createdAt;

    /** Momento del ultimo inicio de sesion; decide cuando regenerar sus recomendaciones. */
    private LocalDateTime lastLoginAt;

    /** Moneda en la que prefiere ver los precios, por defecto {@code COP}. */
    private String preferredCurrency = "COP";

    /** Indica si el usuario acepto el registro de su actividad para personalizar recomendaciones. */
    private boolean consentTracking;

    /** Fecha en que se otorgo o retiro el consentimiento mas reciente. */
    private LocalDateTime consentDate;

    /** Version de la politica de privacidad aceptada. */
    private String consentVersion;

    /** Permiso separado del tracking para enviar ofertas por correo o notificaciones. */
    private boolean marketingOptIn;

    /** Indica si el usuario ya completo sus preferencias de viaje en el onboarding. */
    private boolean onboardingCompleted;

    /**
     * Roles de la cuenta; Spring Security los lee con el prefijo {@code ROLE_}. Los documentos
     * antiguos no traen este campo y quedan con {@code USER}: solo una migracion explicita
     * (scripts/set_admin.py) puede ascender a alguien a {@code ADMIN}.
     */
    private List<String> roles = List.of("USER");

    /** Version del esquema con que se escribio el documento; 0 o ausente indica documento antiguo. */
    public static final int CURRENT_SCHEMA_VERSION = 1;

    /** Version del esquema con que se guardo este documento. */
    private int schemaVersion;

    /** Fecha de la ultima modificacion del documento. */
    private LocalDateTime updatedAt;

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