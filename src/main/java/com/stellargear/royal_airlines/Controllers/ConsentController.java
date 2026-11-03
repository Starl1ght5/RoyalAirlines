package com.stellargear.royal_airlines.Controllers;

import com.stellargear.royal_airlines.Models.DTOs.ConsentRequest;
import com.stellargear.royal_airlines.Models.Utils.UserPrincipal;
import com.stellargear.royal_airlines.Services.UserService;
import jakarta.validation.Valid;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

/** Consentimiento de seguimiento (opt-in). Sin esto, UserEvents no guarda nada. */
@RestController
@RequiredArgsConstructor
@RequestMapping(path = "/api/v1/users/me/consent")
public class ConsentController {

  private final UserService userService;

  /**
   * Devuelve el consentimiento de seguimiento vigente.
   *
   * @param principal usuario extraido del token JWT.
   * @return estado de seguimiento, opt-in de marketing y fecha del consentimiento.
   */
  @GetMapping
  public Map<String, Object> get(@AuthenticationPrincipal UserPrincipal principal) {
    return userService.getConsent(principal.getUserID());
  }

  /**
   * Registra el consentimiento de seguimiento del usuario.
   *
   * @param principal usuario extraido del token JWT.
   * @param request consentimiento enviado por la app.
   * @return estado de seguimiento y opt-in de marketing ya guardados.
   */
  @PutMapping
  public Map<String, Object> put(@AuthenticationPrincipal UserPrincipal principal,
                                 @Valid @RequestBody ConsentRequest request) {
    return userService.updateConsent(principal.getUserID(), request);
  }
}
