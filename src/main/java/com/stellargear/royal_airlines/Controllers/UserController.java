package com.stellargear.royal_airlines.Controllers;

import com.stellargear.royal_airlines.Models.DTOs.LoginRequest;
import com.stellargear.royal_airlines.Models.DTOs.RegisterRequest;
import com.stellargear.royal_airlines.Models.DTOs.TokenResponse;
import com.stellargear.royal_airlines.Services.UserService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
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
}