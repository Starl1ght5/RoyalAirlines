package com.stellargear.royal_airlines.Services;

import com.stellargear.royal_airlines.Models.DTOs.DeviceRegisterRequest;
import com.stellargear.royal_airlines.Models.Entities.DeviceToken;
import com.stellargear.royal_airlines.Repositories.DeviceTokenRepository;
import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

/** Alta, baja y consulta de tokens FCM por usuario. */
@Service
@RequiredArgsConstructor
public class DeviceTokenService {

  private final DeviceTokenRepository repository;

  /**
   * Registra el token para el usuario. Si el token ya existia (de este u otro usuario) se
   * reasigna al usuario actual y se actualiza {@code lastSeenAt}.
   *
   * @param userId propietario del token.
   * @param request token y datos del dispositivo.
   * @return token guardado.
   */
  public DeviceToken register(String userId, DeviceRegisterRequest request) {
    Instant now = Instant.now();
    DeviceToken existing = repository.findByToken(request.token()).orElse(null);
    String id = existing == null ? null : existing.id();
    Instant createdAt = existing == null ? now : existing.createdAt();

    return repository.save(new DeviceToken(
        id, userId, request.token(), request.platform(), request.appVersion(), createdAt, now));
  }

  /** Borra el token solo si pertenece al usuario que lo pide. */
  public void unregister(String userId, String token) {
    repository.deleteByTokenAndUserId(token, userId);
  }

  /**
   * Lista los tokens FCM activos de un usuario.
   *
   * @param userId identificador del usuario.
   * @return tokens registrados para el usuario.
   */
  public List<String> tokensOf(String userId) {
    return repository.findByUserId(userId).stream().map(DeviceToken::token).toList();
  }

  /** Tokens de varios usuarios de una sola consulta, agrupados por usuario. */
  public Map<String, List<String>> tokensByUser(Collection<String> userIds) {
    return repository.findByUserIdIn(userIds).stream()
        .collect(Collectors.groupingBy(DeviceToken::userId,
            Collectors.mapping(DeviceToken::token, Collectors.toList())));
  }

  /** Limpieza de tokens que FCM reporto como invalidos o desinstalados. */
  public void removeTokens(Collection<String> tokens) {
    if (!tokens.isEmpty()) {
      repository.deleteByTokenIn(tokens);
    }
  }
}
