package com.stellargear.royal_airlines.Controllers;

import com.stellargear.royal_airlines.Models.DTOs.UserPreferencesRequest;
import com.stellargear.royal_airlines.Models.Entities.UserPreferences;
import com.stellargear.royal_airlines.Models.Utils.UserPrincipal;
import com.stellargear.royal_airlines.Services.UserPreferencesService;
import jakarta.validation.Valid;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

/**
 * Expone las preferencias de viaje del usuario autenticado.
 */
@RestController
@RequiredArgsConstructor
@RequestMapping(path = "/api/v1/users/me/preferences")
public class UserPreferencesController {

  private final UserPreferencesService preferencesService;

  /**
   * Devuelve las preferencias guardadas del usuario.
   *
   * <p>Sin preferencias guardadas responde 200 {@code {"configured": false}}. NO usar 404/204
   * con cuerpo vacio: el {@code ApiClient} de Flutter trata un cuerpo vacio como exito con
   * {@code data=null}.</p>
   *
   * @param principal usuario extraido del token JWT.
   * @return preferencias guardadas o un objeto con {@code configured=false}.
   */
  @GetMapping
  public Object get(@AuthenticationPrincipal UserPrincipal principal) {
    return preferencesService.find(principal.getUserID())
        .<Object>map(p -> p)
        .orElseGet(() -> Map.of("configured", false));
  }

  /**
   * Crea o reemplaza las preferencias del usuario.
   *
   * @param principal usuario extraido del token JWT.
   * @param request preferencias nuevas ya validadas.
   * @return preferencias guardadas.
   */
  @PutMapping
  public UserPreferences put(@AuthenticationPrincipal UserPrincipal principal,
                             @Valid @RequestBody UserPreferencesRequest request) {
    return preferencesService.upsert(principal.getUserID(), request);
  }

  /**
   * Borra las preferencias del usuario.
   *
   * @param principal usuario extraido del token JWT.
   */
  @DeleteMapping
  @ResponseStatus(HttpStatus.NO_CONTENT)
  public void delete(@AuthenticationPrincipal UserPrincipal principal) {
    preferencesService.delete(principal.getUserID());
  }
}
