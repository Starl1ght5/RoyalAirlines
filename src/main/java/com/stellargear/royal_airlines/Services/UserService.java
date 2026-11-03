package com.stellargear.royal_airlines.Services;

import com.stellargear.royal_airlines.Models.DTOs.ChangePasswordRequest;
import com.stellargear.royal_airlines.Models.DTOs.ConsentRequest;
import com.stellargear.royal_airlines.Models.DTOs.ForgotPasswordRequest;
import com.stellargear.royal_airlines.Models.DTOs.LoginRequest;
import com.stellargear.royal_airlines.Models.DTOs.RegisterRequest;
import com.stellargear.royal_airlines.Models.DTOs.ResetPasswordRequest;
import com.stellargear.royal_airlines.Models.DTOs.UpdateProfileRequest;
import com.stellargear.royal_airlines.Models.DTOs.UserProfileDTO;
import com.stellargear.royal_airlines.Models.Entities.User;
import com.stellargear.royal_airlines.Repositories.UserRepository;
import com.stellargear.royal_airlines.Utils.BadRequestException;
import com.stellargear.royal_airlines.Utils.ConflictException;
import com.stellargear.royal_airlines.Utils.NotFoundException;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.Map;

/**
 * Gestiona el registro, el inicio de sesion y la verificacion de las cuentas.
 */
@Service
@RequiredArgsConstructor
public class UserService {

    private static final Logger logger = LoggerFactory.getLogger(UserService.class);

    /** Fuente criptografica para los codigos de recuperacion; no se usa {@code Random}. */
    private static final SecureRandom SECURE_RANDOM = new SecureRandom();

    /** Vigencia del codigo enviado por {@code POST /auth/forgot-password}. */
    private static final long RESET_CODE_MINUTES = 30;

    private final UserRepository userRepository;
    private final JwtService jwtService;
    private final AuthenticationManager authenticationManager;

    private final BCryptPasswordEncoder encoder = new BCryptPasswordEncoder(12);

    /**
     * Crea una cuenta nueva, todavia sin verificar.
     *
     * @param request correo y contrasena ya validados.
     * @throws ConflictException si el correo ya esta registrado.
     */
    public void registerNewUser(RegisterRequest request) {
        if (isEmailTaken(request.email())) {
            throw new ConflictException("El email ya esta registrado");
        }

        User newUser = new User();
        newUser.setEmail(request.email());
        newUser.setPassword(encoder.encode(request.password()));
        // El frontend ya envia el nombre: se guarda como username para que
        // `GET /users/me` devuelva el perfil completo en vez de un vacio.
        if (request.fullName() != null && !request.fullName().isBlank()) {
            newUser.setUsername(request.fullName().trim());
        }
        newUser.setCreatedAt(LocalDateTime.now());
        newUser.setSchemaVersion(User.CURRENT_SCHEMA_VERSION);
        newUser.setUpdatedAt(LocalDateTime.now());

        try {
            userRepository.save(newUser);
        } catch (DuplicateKeyException e) {
            throw new ConflictException("El email ya esta registrado");
        }

        logger.info("Usuario registrado, id: {}", newUser.getUserID());
    }

    /**
     * Autentica al usuario y emite su token.
     *
     * @param request correo y contrasena.
     * @return JWT de la aplicacion.
     * @throws org.springframework.security.authentication.BadCredentialsException si las credenciales
     *         no son correctas, lo que el manejador global traduce a 401.
     */
    public String login(LoginRequest request) {
        authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(request.email(), request.password())
        );

        User loggingUser = searchForUser(request.email());
        loggingUser.setLastLoginAt(LocalDateTime.now());
        userRepository.save(loggingUser);

        return jwtService.generateToken(loggingUser);
    }

    /**
     * Marca la cuenta indicada como verificada e invalida su codigo.
     *
     * @param verificationCode codigo recibido por correo.
     * @throws BadRequestException si el codigo no corresponde a ninguna cuenta pendiente de verificar.
     */
    public void verifyUser(String verificationCode) {
        if (verificationCode == null || verificationCode.isBlank()) {
            throw new BadRequestException("Codigo de verificacion invalido");
        }

        User requestingUser = userRepository.searchFromToken(verificationCode);

        if (requestingUser == null) {
            throw new BadRequestException("Codigo de verificacion invalido");
        }

        requestingUser.setVerified(true);
        requestingUser.setVerificationCode("");

        userRepository.save(requestingUser);

        logger.info("Correo verificado, id: {}", requestingUser.getUserID());
    }

    /**
     * Devuelve el perfil del usuario autenticado.
     *
     * @param userID identificador que viaja en el JWT.
     * @return perfil listo para el cliente.
     */
    public UserProfileDTO getProfile(String userID) {
        return toProfile(loadUser(userID), null);
    }

    /**
     * Actualiza el nombre visible y el correo de la cuenta autenticada.
     *
     * <p>El JWT usa el correo como sujeto, por lo que al cambiarlo el token anterior deja de
     * valer: aqui se emite uno nuevo y se devuelve en la respuesta para que la app lo guarde y
     * la sesion siga viva.</p>
     *
     * @param userID identificador que viaja en el JWT.
     * @param request datos nuevos ya validados.
     * @return perfil actualizado junto con el token renovado.
     * @throws ConflictException si el correo nuevo ya pertenece a otra cuenta.
     */
    public UserProfileDTO updateProfile(String userID, UpdateProfileRequest request) {
        User user = loadUser(userID);

        String newEmail = request.email().trim();

        if (!newEmail.equals(user.getEmail())) {
            if (userRepository.isEmailTaken(newEmail) != null) {
                throw new ConflictException("El email ya esta registrado");
            }
            user.setEmail(newEmail);
        }

        user.setUsername(request.fullName().trim());
        user.setUpdatedAt(LocalDateTime.now());

        try {
            userRepository.save(user);
        } catch (DuplicateKeyException e) {
            // Carrera entre dos ediciones simultaneas: el indice unico del correo gana.
            throw new ConflictException("El email ya esta registrado");
        }

        logger.info("Perfil actualizado, id: {}", user.getUserID());

        return toProfile(user, jwtService.generateToken(user));
    }

    /**
     * Cambia la contrasena de una cuenta autenticada.
     *
     * @param userID identificador que viaja en el JWT.
     * @param request contrasena actual y nueva ya validadas.
     * @throws BadRequestException si la cuenta no tiene contrasena propia
     *         (creada solo con Google/Apple) o si la contrasena actual no coincide.
     */
    public void changePassword(String userID, ChangePasswordRequest request) {
        User user = loadUser(userID);

        if (user.getPassword() == null || user.getPassword().isBlank()) {
            throw new BadRequestException("Tu cuenta usa inicio de sesion con Google/Apple y no tiene contrasena propia");
        }

        if (!encoder.matches(request.currentPassword(), user.getPassword())) {
            throw new BadRequestException("La contrasena actual no es correcta");
        }

        user.setPassword(encoder.encode(request.newPassword()));
        // Una contrasena nueva invalida cualquier codigo de recuperacion pendiente.
        user.setPasswordResetCode(null);
        user.setPasswordResetExpiresAt(null);
        user.setUpdatedAt(LocalDateTime.now());
        userRepository.save(user);

        logger.info("Contrasena actualizada, id: {}", user.getUserID());
    }

    /**
     * Genera un codigo de recuperacion para la cuenta indicada.
     *
     * <p>La respuesta es la misma exista o no el correo, para que el endpoint no sirva para
     * enumerar cuentas. Como el backend no tiene un servidor SMTP configurado, el envio queda
     * simulado: el codigo se guarda con vencimiento y se escribe en el log del servidor.</p>
     *
     * @param request correo que pidio la recuperacion.
     */
    public void requestPasswordReset(ForgotPasswordRequest request) {
        User user = userRepository.searchByEmail(request.email().trim());

        if (user == null) {
            logger.info("Solicitud de recuperacion para un correo no registrado");
            return;
        }

        String code = String.format("%06d", SECURE_RANDOM.nextInt(1_000_000));

        user.setPasswordResetCode(code);
        user.setPasswordResetExpiresAt(LocalDateTime.now().plusMinutes(RESET_CODE_MINUTES));
        user.setUpdatedAt(LocalDateTime.now());
        userRepository.save(user);

        logger.info("Codigo de recuperacion para {}: {} (expira en {} minutos)",
                user.getEmail(), code, RESET_CODE_MINUTES);
    }

    /**
     * Restablece la contrasena con el codigo emitido por {@code POST /auth/forgot-password}.
     *
     * <p>Un correo inexistente, un codigo equivocado y un codigo vencido responden igual: asi el
     * endpoint no sirve para descubrir cuentas ni para saber si un codigo fue correcto en algun
     * momento.</p>
     *
     * @param request correo, codigo y contrasena nueva ya validados.
     * @throws BadRequestException si el codigo no es valido o ya vencio.
     */
    public void resetPassword(ResetPasswordRequest request) {
        User user = userRepository.searchByEmail(request.email().trim());

        if (user == null || !isResetCodeValid(user, request.code())) {
            throw new BadRequestException("El codigo es invalido o ha expirado");
        }

        user.setPassword(encoder.encode(request.newPassword()));
        // El codigo es de un solo uso: se borra junto con su vencimiento.
        user.setPasswordResetCode(null);
        user.setPasswordResetExpiresAt(null);
        user.setUpdatedAt(LocalDateTime.now());
        userRepository.save(user);

        logger.info("Contrasena restablecida, id: {}", user.getUserID());
    }

    /**
     * Comprueba que el codigo exista, coincida y no haya vencido.
     *
     * <p>La comparacion es de tiempo constante para no filtrar, por el tiempo de respuesta, cuantos
     * digitos iniciales del codigo eran correctos.</p>
     *
     * @param user cuenta que pidio la recuperacion.
     * @param code codigo enviado por el cliente.
     * @return {@code true} solo si el codigo es el vigente.
     */
    private boolean isResetCodeValid(User user, String code) {
        if (user.getPasswordResetCode() == null || user.getPasswordResetExpiresAt() == null) {
            return false;
        }

        if (!user.getPasswordResetExpiresAt().isAfter(LocalDateTime.now())) {
            return false;
        }

        return MessageDigest.isEqual(
                user.getPasswordResetCode().getBytes(StandardCharsets.UTF_8),
                code.getBytes(StandardCharsets.UTF_8));
    }

    /**
     * Devuelve el consentimiento de seguimiento vigente del usuario.
     *
     * @param userID identificador que viaja en el JWT.
     * @return mapa con {@code tracking}, {@code marketingOptIn} y {@code consentDate}.
     * @throws NotFoundException si la cuenta ya no existe.
     */
    public Map<String, Object> getConsent(String userID) {
        User user = loadUser(userID);
        return Map.of("tracking", user.isConsentTracking(),
                "marketingOptIn", user.isMarketingOptIn(),
                "consentDate", String.valueOf(user.getConsentDate()));
    }

    /**
     * Registra el consentimiento de seguimiento del usuario.
     *
     * <p>{@code marketingOptIn} y {@code consentVersion} son opcionales: si no llegan (o la
     * version viene en blanco) se conserva el valor anterior.</p>
     *
     * @param userID identificador que viaja en el JWT.
     * @param request consentimiento enviado por la app.
     * @return mapa con {@code tracking} y {@code marketingOptIn} ya guardados.
     * @throws NotFoundException si la cuenta ya no existe.
     */
    public Map<String, Object> updateConsent(String userID, ConsentRequest request) {
        User user = loadUser(userID);
        user.setConsentTracking(request.tracking());
        user.setConsentDate(LocalDateTime.now());

        if (request.marketingOptIn() != null) {
            user.setMarketingOptIn(request.marketingOptIn());
        }

        if (request.consentVersion() != null && !request.consentVersion().isBlank()) {
            user.setConsentVersion(request.consentVersion());
        }

        userRepository.save(user);
        return Map.of("tracking", user.isConsentTracking(), "marketingOptIn", user.isMarketingOptIn());
    }

    /**
     * Busca la cuenta del usuario autenticado.
     *
     * @param userID identificador que viaja en el JWT.
     * @return usuario encontrado.
     * @throws NotFoundException si la cuenta ya no existe.
     */
    private User loadUser(String userID) {
        return userRepository.findById(userID)
                .orElseThrow(() -> new NotFoundException("Usuario no encontrado"));
    }

    /**
     * Arma la vista del perfil con los nombres de campo que consume la app.
     *
     * @param user usuario de la base de datos.
     * @param token token renovado, o {@code null} cuando solo se consulta el perfil.
     * @return perfil listo para el cliente.
     */
    private UserProfileDTO toProfile(User user, String token) {
        return new UserProfileDTO(
                user.getUserID(),
                user.getUsername() == null ? "" : user.getUsername(),
                user.getEmail(),
                null,
                token
        );
    }

    /**
     * Indica si un correo ya pertenece a una cuenta.
     *
     * @param requestedEmail correo a comprobar.
     * @return {@code true} si el correo esta en uso.
     */
    public boolean isEmailTaken(String requestedEmail) {
        return userRepository.isEmailTaken(requestedEmail) != null;
    }

    /**
     * Busca un usuario por su correo.
     *
     * @param requestedEmail correo del usuario.
     * @return usuario encontrado o {@code null}.
     */
    public User searchForUser(String requestedEmail) {
        return userRepository.searchByEmail(requestedEmail);
    }
}
