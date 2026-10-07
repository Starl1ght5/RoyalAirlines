package com.stellargear.royal_airlines.Services;

import com.stellargear.royal_airlines.Models.DTOs.LoginRequest;
import com.stellargear.royal_airlines.Models.DTOs.RegisterRequest;
import com.stellargear.royal_airlines.Models.DTOs.UserDTO;
import com.stellargear.royal_airlines.Models.Entities.User;
import com.stellargear.royal_airlines.Repositories.UserRepository;
import com.stellargear.royal_airlines.Utils.ConflictException;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

/**
 * Gestiona el registro, el inicio de sesion y la verificacion de las cuentas.
 */
@Service
@RequiredArgsConstructor
public class UserService {

    private static final Logger logger = LoggerFactory.getLogger(UserService.class);

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

        return jwtService.generateToken(searchForUser(request.email()));
    }

    /**
     * Marca la cuenta indicada como verificada e invalida su codigo.
     *
     * @param verificationCode codigo recibido por correo.
     * @throws ResponseStatusException con codigo 400 si el codigo no corresponde a ninguna cuenta
     *                               pendiente de verificar.
     */
    public void verifyUser(String verificationCode) {
        if (verificationCode == null || verificationCode.isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Codigo de verificacion invalido");
        }

        User requestingUser = userRepository.searchFromToken(verificationCode);

        if (requestingUser == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Codigo de verificacion invalido");
        }

        requestingUser.setVerified(true);
        requestingUser.setVerificationCode("");

        userRepository.save(requestingUser);

        logger.info("Correo verificado, id: {}", requestingUser.getUserID());
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

    /**
     * Convierte un usuario de la base de datos en su version para el cliente.
     *
     * @param requestedObject usuario de la base de datos.
     * @return usuario sin el hash de la contrasena, que nunca sale de la API.
     */
    public UserDTO objectToDto(User requestedObject) {
        return new UserDTO(
                requestedObject.getUserID(),
                requestedObject.getUsername(),
                requestedObject.getEmail(),
                null,
                requestedObject.isVerified()
        );
    }
}