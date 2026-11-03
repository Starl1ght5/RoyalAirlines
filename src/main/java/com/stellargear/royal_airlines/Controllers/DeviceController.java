package com.stellargear.royal_airlines.Controllers;

import com.stellargear.royal_airlines.Models.DTOs.DeviceRegisterRequest;
import com.stellargear.royal_airlines.Models.Utils.UserPrincipal;
import com.stellargear.royal_airlines.Services.DeviceTokenService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Registro de dispositivos para notificaciones push. Requiere JWT. */
@RestController
@RequiredArgsConstructor
@RequestMapping(path = "/api/v1/users/me/devices")
public class DeviceController {

  private final DeviceTokenService deviceTokenService;

  /**
   * Registra o actualiza el token FCM del dispositivo.
   *
   * <p>Es un upsert idempotente: la app lo llama al iniciar sesion y cada vez que FCM rota el
   * token.</p>
   *
   * @param principal usuario extraido del token JWT.
   * @param request token y datos del dispositivo.
   */
  @PutMapping
  @ResponseStatus(HttpStatus.NO_CONTENT)
  public void register(@AuthenticationPrincipal UserPrincipal principal,
                       @Valid @RequestBody DeviceRegisterRequest request) {
    deviceTokenService.register(principal.getUserID(), request);
  }

  /**
   * Elimina el token del dispositivo del usuario.
   *
   * <p>Se llama al cerrar sesion o al apagar las alertas. Si el token no existe no pasa nada.</p>
   *
   * @param principal usuario extraido del token JWT.
   * @param token token FCM a eliminar.
   */
  @DeleteMapping(path = "/{token}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  public void unregister(@AuthenticationPrincipal UserPrincipal principal,
                         @PathVariable String token) {
    deviceTokenService.unregister(principal.getUserID(), token);
  }
}
