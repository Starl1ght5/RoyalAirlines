package com.stellargear.royal_airlines.Controllers;

import com.stellargear.royal_airlines.Models.DTOs.FavoriteRequest;
import com.stellargear.royal_airlines.Models.Entities.Favorite;
import com.stellargear.royal_airlines.Models.Entities.Favorite.TargetType;
import com.stellargear.royal_airlines.Models.Utils.UserPrincipal;
import com.stellargear.royal_airlines.Services.FavoriteService;
import jakarta.validation.Valid;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

/**
 * Expone los favoritos del usuario autenticado.
 */
@RestController
@RequiredArgsConstructor
@RequestMapping(path = "/api/v1/favorites")
public class FavoriteController {

  private final FavoriteService favoriteService;

  /**
   * Lista los favoritos del usuario, del mas reciente al mas antiguo.
   *
   * @param principal usuario extraido del token JWT.
   * @return favoritos del usuario.
   */
  @GetMapping
  public List<Favorite> list(@AuthenticationPrincipal UserPrincipal principal) {
    return favoriteService.list(principal.getUserID());
  }

  /**
   * Agrega un favorito de forma idempotente.
   *
   * @param principal usuario extraido del token JWT.
   * @param request tipo e identificador del elemento a guardar.
   * @return favorito guardado o el existente.
   */
  @PostMapping
  @ResponseStatus(HttpStatus.CREATED)
  public Favorite add(@AuthenticationPrincipal UserPrincipal principal,
                      @Valid @RequestBody FavoriteRequest request) {
    return favoriteService.add(principal.getUserID(), request.targetType(), request.targetId());
  }

  /**
   * Elimina un favorito.
   *
   * @param principal usuario extraido del token JWT.
   * @param targetType tipo de elemento, en mayusculas: {@code DESTINATION} o {@code FLIGHT}.
   * @param targetId identificador del destino o del vuelo.
   */
  @DeleteMapping("/{targetType}/{targetId}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  public void remove(@AuthenticationPrincipal UserPrincipal principal,
                     @PathVariable TargetType targetType, @PathVariable String targetId) {
    favoriteService.remove(principal.getUserID(), targetType, targetId);
  }
}
