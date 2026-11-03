package com.stellargear.royal_airlines.Controllers;

import com.stellargear.royal_airlines.Models.DTOs.EventBatchRequest;
import com.stellargear.royal_airlines.Models.Utils.UserPrincipal;
import com.stellargear.royal_airlines.Services.UserEventService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

/**
 * Recibe los lotes de eventos de comportamiento enviados por la app.
 *
 * <p>Pendiente: rate limit (Bucket4j o gateway). Es el endpoint mas expuesto a abuso.</p>
 */
@RestController
@RequiredArgsConstructor
@RequestMapping(path = "/api/v1/events")
public class UserEventController {

  private final UserEventService eventService;

  /**
   * Guarda un lote de eventos si el usuario tiene el seguimiento activo.
   *
   * @param principal usuario extraido del token JWT.
   * @param request lote de eventos a procesar.
   * @return resumen con los eventos aceptados y rechazados.
   */
  @PostMapping
  @ResponseStatus(HttpStatus.ACCEPTED)
  public EventBatchRequest.Result ingest(@AuthenticationPrincipal UserPrincipal principal,
                                         @Valid @RequestBody EventBatchRequest request) {
    return eventService.ingest(principal.getUserID(), request.events());
  }
}
