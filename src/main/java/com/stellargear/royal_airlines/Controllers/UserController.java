package com.stellargear.royal_airlines.Controllers;

import com.stellargear.royal_airlines.Models.DTOs.LoginRequest;
import com.stellargear.royal_airlines.Models.DTOs.RegisterRequest;
import com.stellargear.royal_airlines.Models.DTOs.TokenResponse;
import com.stellargear.royal_airlines.Models.DTOs.UpdateProfileRequest;
import com.stellargear.royal_airlines.Models.DTOs.UserProfileDTO;
import com.stellargear.royal_airlines.Models.Utils.UserPrincipal;
import com.stellargear.royal_airlines.Services.UserService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Endpoints de registro, inicio de sesion y verificacion de correo.
 */
@RestController
@RequiredArgsConstructor
@RequestMapping(path = "/api/v1/users")
public class UserController {

    private final UserService userService;

    /**
     * Registra un usuario nuevo con correo y contrasena.
     *
     * @param request datos del registro ya validados.
     */
    @PostMapping(path = "/register")
    @ResponseStatus(HttpStatus.CREATED)
    public void registerUser(@Valid @RequestBody RegisterRequest request) {
        userService.registerNewUser(request);
    }

    /**
     * Autentica al usuario y devuelve el token de sesion.
     *
     * @param request correo y contrasena ya validados.
     * @return token JWT de la aplicacion.
     */
    @PostMapping(path = "/login")
    public TokenResponse loginUser(@Valid @RequestBody LoginRequest request) {
        return new TokenResponse(userService.login(request));
    }

    /**
     * Marca la cuenta como verificada a partir del codigo recibido por correo.
     *
     * @param verificationCode codigo de verificacion unico.
     */
    @GetMapping(path = "/verify")
    public void verifyUser(@RequestParam @NotBlank String verificationCode) {
        userService.verifyUser(verificationCode);
    }

    /**
     * Devuelve el perfil de la cuenta autenticada.
     *
     * @param principal usuario que sale del token JWT.
     * @return nombre, correo e id actuales.
     */
    @GetMapping(path = "/me")
    public UserProfileDTO getProfile(@AuthenticationPrincipal UserPrincipal principal) {
        return userService.getProfile(principal.getUserID());
    }

    /**
     * Actualiza el nombre y el correo de la cuenta autenticada.
     *
     * <p>La respuesta trae un token nuevo porque el JWT usa el correo como sujeto: si la
     * persona cambia su correo, el token anterior deja de valer.</p>
     *
     * @param principal usuario que sale del token JWT.
     * @param request datos nuevos ya validados.
     * @return perfil actualizado con un token renovado.
     */
    @PutMapping(path = "/me")
    public UserProfileDTO updateProfile(@AuthenticationPrincipal UserPrincipal principal,
                                        @Valid @RequestBody UpdateProfileRequest request) {
        return userService.updateProfile(principal.getUserID(), request);
    }
}