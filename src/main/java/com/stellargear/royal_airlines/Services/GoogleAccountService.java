package com.stellargear.royal_airlines.Services;

import com.stellargear.royal_airlines.Models.Entities.User;
import com.stellargear.royal_airlines.Repositories.UserRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;
import org.springframework.security.oauth2.core.DelegatingOAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidatorResult;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtException;
import org.springframework.security.oauth2.jwt.JwtTimestampValidator;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

/**
 * Logica compartida del inicio de sesion con Google.
 *
 * <p>La usan tanto el flujo web, que llega por redireccion, como el movil, que envia el
 * {@code idToken}. En ambos casos el token de Google se valida contra las claves publicas de
 * Google antes de emitir un JWT propio.</p>
 */
@Service
public class GoogleAccountService {

    /** Ubicacion de las claves publicas con las que Google firma sus tokens. */
    private static final String GOOGLE_JWKS = "https://www.googleapis.com/oauth2/v3/certs";

    private final UserRepository userRepository;
    private final JwtService jwtService;
    private final NimbusJwtDecoder googleDecoder;

    /**
     * Construye el servicio y deja listo el validador de tokens de Google.
     *
     * @param userRepository repositorio de usuarios.
     * @param jwtService servicio que emite los tokens de la aplicacion.
     * @param webClientId identificador de cliente de Google de tipo Web, el mismo que la app movil
     *                    declara como {@code serverClientId}.
     */
    public GoogleAccountService(UserRepository userRepository,
                                JwtService jwtService,
                                @Value("${spring.security.oauth2.client.registration.google.client-id}") String webClientId) {
        this.userRepository = userRepository;
        this.jwtService = jwtService;

        OAuth2TokenValidator<Jwt> issuerValidator = jwt -> {
            String issuer = jwt.getClaimAsString("iss");
            return ("https://accounts.google.com".equals(issuer) || "accounts.google.com".equals(issuer))
                    ? OAuth2TokenValidatorResult.success()
                    : OAuth2TokenValidatorResult.failure(new OAuth2Error("invalid_token", "Emisor invalido", null));
        };

        OAuth2TokenValidator<Jwt> audienceValidator = jwt -> {
            List<String> audience = jwt.getAudience();
            return (audience != null && audience.contains(webClientId))
                    ? OAuth2TokenValidatorResult.success()
                    : OAuth2TokenValidatorResult.failure(new OAuth2Error("invalid_token", "Audiencia invalida", null));
        };

        this.googleDecoder = NimbusJwtDecoder.withJwkSetUri(GOOGLE_JWKS).build();
        this.googleDecoder.setJwtValidator(
                new DelegatingOAuth2TokenValidator<>(new JwtTimestampValidator(), issuerValidator, audienceValidator));
    }

    /**
     * Autentica a un usuario movil con el token que Google le entrego.
     *
     * @param idToken token de identidad firmado por Google.
     * @return JWT de Royal Airlines.
     * @throws ResponseStatusException con codigo 400 si falta el token o con codigo 401 si no supera
     *                               la validacion o la cuenta no es utilizable.
     */
    public String loginWithIdToken(String idToken) {
        if (idToken == null || idToken.isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "idToken requerido");
        }

        Jwt googleToken;

        try {
            googleToken = googleDecoder.decode(idToken);
        } catch (JwtException e) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Token de Google invalido");
        }

        User user = resolveUser(googleToken.getSubject(),
                googleToken.getClaimAsString("email"),
                googleToken.getClaimAsBoolean("email_verified"));

        return jwtService.generateToken(user);
    }

    /**
     * Busca la cuenta local del usuario de Google o la crea si no existe.
     *
     * <p>Un usuario que ya entro con Google se reconoce por su identificador {@code sub} y no por
     * el correo. Si el correo ya tiene una cuenta local sin verificar, se descarta su contrasena:
     * pudo crearla alguien con el correo de la victima.</p>
     *
     * @param sub identificador estable de la cuenta en Google.
     * @param email correo informado por Google.
     * @param emailVerified indica si Google verifico ese correo.
     * @return usuario local listo para emitir el token.
     * @throws ResponseStatusException con codigo 401 si Google no verifico el correo.
     */
    public User resolveUser(String sub, String email, Boolean emailVerified) {
        if (sub == null || email == null || !Boolean.TRUE.equals(emailVerified)) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Cuenta de Google sin email verificado");
        }

        User user = userRepository.findByGoogleSub(sub);

        if (user != null) {
            return user;
        }

        user = userRepository.searchByEmail(email);

        if (user == null) {
            user = new User();
            user.setEmail(email);

        } else if (!user.isVerified()) {
            user.setPassword(null);
        }

        user.setGoogleSub(sub);
        user.setVerified(true);
        user.setVerificationCode("");

        try {
            return userRepository.save(user);
        } catch (DuplicateKeyException e) {
            return userRepository.searchByEmail(email);
        }
    }
}