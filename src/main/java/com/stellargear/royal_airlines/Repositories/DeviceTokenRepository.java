package com.stellargear.royal_airlines.Repositories;

import com.stellargear.royal_airlines.Models.Entities.DeviceToken;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.mongodb.repository.MongoRepository;

/**
 * Acceso a los tokens FCM de los dispositivos.
 */
public interface DeviceTokenRepository extends MongoRepository<DeviceToken, String> {
  Optional<DeviceToken> findByToken(String token);
  List<DeviceToken> findByUserId(String userId);
  List<DeviceToken> findByUserIdIn(Collection<String> userIds);
  long deleteByTokenAndUserId(String token, String userId);
  long deleteByTokenIn(Collection<String> tokens);
  void deleteByUserId(String userId);
}
