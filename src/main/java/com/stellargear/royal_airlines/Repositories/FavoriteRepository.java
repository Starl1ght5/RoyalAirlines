package com.stellargear.royal_airlines.Repositories;

import com.stellargear.royal_airlines.Models.Entities.Favorite;
import com.stellargear.royal_airlines.Models.Entities.Favorite.TargetType;
import java.util.List;
import java.util.Optional;
import org.springframework.data.mongodb.repository.MongoRepository;

/**
 * Acceso a los favoritos de los usuarios.
 */
public interface FavoriteRepository extends MongoRepository<Favorite, String> {
  List<Favorite> findByUserIdOrderByCreatedAtDesc(String userId);
  Optional<Favorite> findByUserIdAndTargetTypeAndTargetId(String userId, TargetType type, String targetId);
  long countByUserId(String userId);
  long deleteByUserIdAndTargetTypeAndTargetId(String userId, TargetType type, String targetId);
  void deleteByUserId(String userId);
}
