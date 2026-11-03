package com.stellargear.royal_airlines.Controllers;

import com.stellargear.royal_airlines.Models.DTOs.ChangePasswordRequest;
import com.stellargear.royal_airlines.Models.DTOs.ForgotPasswordRequest;
import com.stellargear.royal_airlines.Models.DTOs.MessageResponse;
import com.stellargear.royal_airlines.Models.DTOs.ResetPasswordRequest;
import com.stellargear.royal_airlines.Models.Utils.UserPrincipal;
import com.stellargear.royal_airlines.Services.GoogleAccountService;
import com.stellargear.royal_airlines.Services.UserService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * Autenticacion que no es el login con correo y contrasena: login social con Google y cambio
 * o recuperacion de contrasena.
 *
 * <p>Todas las rutas cuelgan de {@code /api/v1/auth}.</p>
 */
@RestController
@RequiredArgsConstructor
@RequestMapping(path = "/api/v1/auth")
public class AuthController {

    private final GoogleAccountService googleAccountService;
    private final UserService userService;

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

    /**
     * Cambia la contrasena del usuario autenticado.
     *
     * <p>Requiere el token de sesion y, ademas, la contrasena actual: tener una sesion abierta no
     * debe bastar para cambiar la credencial.</p>
     *
     * @param principal usuario que sale del token JWT.
     * @param request contrasena actual y nueva.
     * @return confirmacion de la operacion.
     */
    @PostMapping(path = "/change-password")
    public MessageResponse changePassword(@AuthenticationPrincipal UserPrincipal principal,
                                          @Valid @RequestBody ChangePasswordRequest request) {
        userService.changePassword(principal.getUserID(), request);
        return new MessageResponse(true, "Contrasena actualizada");
    }

    /**
     * Pide instrucciones de recuperacion para un correo.
     *
     * <p>No requiere token. Siempre responde con exito, exista o no la cuenta, para no revelar
     * que correos estan registrados.</p>
     *
     * @param request correo al que se enviarian las instrucciones.
     * @return mensaje neutro, igual para cuentas existentes e inexistentes.
     */
    @PostMapping(path = "/forgot-password")
    public MessageResponse forgotPassword(@Valid @RequestBody ForgotPasswordRequest request) {
        userService.requestPasswordReset(request);
        return new MessageResponse(true, "Si el correo existe, recibiras instrucciones");
    }

    /**
     * Restablece la contrasena con el codigo que se envio por correo.
     *
     * <p>No requiere token: quien olvido su contrasena no puede autenticarse. El codigo demuestra
     * el control del buzon y es de un solo uso.</p>
     *
     * @param request correo, codigo y contrasena nueva.
     * @return confirmacion de la operacion.
     */
    @PostMapping(path = "/reset-password")
    public MessageResponse resetPassword(@Valid @RequestBody ResetPasswordRequest request) {
        userService.resetPassword(request);
        return new MessageResponse(true, "Contrasena actualizada");
    }
}
