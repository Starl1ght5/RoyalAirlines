package com.stellargear.royal_airlines.Controllers;

import com.stellargear.royal_airlines.Services.GoogleAccountService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * Autenticacion con Google en el flujo movil.
 *
 * <p>La app envia el {@code idToken} que Google firmo y la API responde con el JWT propio.</p>
 */
@RestController
@RequiredArgsConstructor
@RequestMapping(path = "/api/v1/auth")
public class GoogleAuthController {

    private final GoogleAccountService googleAccountService;

    /**
     * Cuerpo de la peticion de login movil.
     *
     * @param idToken token de identidad emitido y firmado por Google.
     */
    public record GoogleLoginRequest(@NotBlank(message = "idToken es obligatorio") String idToken) {}

    /**
     * Valida el {@code idToken} de Google y devuelve el token de la aplicacion.
     *
     * <p>No se confia en lo que declara el cliente: el token viene firmado por Google y se
     * validan firma, expiracion, emisor y audiencia antes de emitir el JWT propio.</p>
     *
     * @param request token de identidad de Google.
     * @return mapa con el JWT de Royal Airlines bajo la clave {@code token}.
     */
    @PostMapping(path = "/google")
    public ResponseEntity<Map<String, String>> loginWithGoogle(@Valid @RequestBody GoogleLoginRequest request) {
        String token = googleAccountService.loginWithIdToken(request.idToken());

        return ResponseEntity.ok(Map.of("token", token));
    }
}