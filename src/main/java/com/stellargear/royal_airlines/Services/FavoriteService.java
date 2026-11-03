package com.stellargear.royal_airlines.Services;

import com.stellargear.royal_airlines.Models.Entities.Favorite;
import com.stellargear.royal_airlines.Models.Entities.Favorite.TargetType;
import com.stellargear.royal_airlines.Repositories.FavoriteRepository;
import com.stellargear.royal_airlines.Repositories.FlightRepository;
import com.stellargear.royal_airlines.Repositories.LocationRepository;
import com.stellargear.royal_airlines.Utils.ConflictException;
import com.stellargear.royal_airlines.Utils.NotFoundException;
import java.time.Instant;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.stereotype.Service;

/**
 * Gestiona los destinos y vuelos favoritos del usuario.
 */
@Service
@RequiredArgsConstructor
public class FavoriteService {

  private static final int MAX_PER_USER = 200;

  private final FavoriteRepository favoriteRepository;
  private final LocationRepository locationRepository;
  private final FlightRepository flightRepository;
  private final UserEventService eventService;

  /**
   * Lista los favoritos de un usuario, del mas reciente al mas antiguo.
   *
   * @param userID identificador del usuario.
   * @return favoritos del usuario.
   */
  public List<Favorite> list(String userID) {
    return favoriteRepository.findByUserIdOrderByCreatedAtDesc(userID);
  }

  /**
   * Agrega un favorito de forma idempotente: si ya existe devuelve el existente, sin duplicar
   * ni emitir evento.
   *
   * @param userID identificador del usuario.
   * @param type tipo de elemento.
   * @param targetId identificador del destino o del vuelo.
   * @return favorito guardado o el existente.
   * @throws NotFoundException si el elemento no existe.
   * @throws ConflictException si el usuario alcanzo el limite de favoritos.
   */
  public Favorite add(String userID, TargetType type, String targetId) {
    boolean exists = type == TargetType.DESTINATION
        ? locationRepository.existsById(targetId)
        : flightRepository.existsById(targetId);
    if (!exists) throw new NotFoundException("El elemento no existe");

    var existing = favoriteRepository.findByUserIdAndTargetTypeAndTargetId(userID, type, targetId);
    if (existing.isPresent()) return existing.get();
    if (favoriteRepository.countByUserId(userID) >= MAX_PER_USER) {
      throw new ConflictException("Limite de favoritos alcanzado");
    }
    try {
      Favorite saved = favoriteRepository.insert(new Favorite(null, userID, type, targetId, Instant.now()));
      emit(userID, "favorite_add", type, targetId);
      return saved;
    } catch (DuplicateKeyException race) { // dos toques casi simultaneos
      return favoriteRepository.findByUserIdAndTargetTypeAndTargetId(userID, type, targetId).orElseThrow();
    }
  }

  /**
   * Elimina un favorito y emite el evento correspondiente si existia.
   *
   * @param userID identificador del usuario.
   * @param type tipo de elemento.
   * @param targetId identificador del destino o del vuelo.
   */
  public void remove(String userID, TargetType type, String targetId) {
    if (favoriteRepository.deleteByUserIdAndTargetTypeAndTargetId(userID, type, targetId) > 0) {
      emit(userID, "favorite_remove", type, targetId);
    }
  }

  private void emit(String userID, String eventType, TargetType type, String targetId) {
    eventService.record(userID, eventType,
        type == TargetType.DESTINATION ? targetId : null,
        type == TargetType.FLIGHT ? targetId : null,
        null, "favorites", null);
  }
}
