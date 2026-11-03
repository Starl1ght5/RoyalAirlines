package com.stellargear.royal_airlines.Repositories;

import com.stellargear.royal_airlines.Models.Entities.UserEvent;
import org.springframework.data.mongodb.repository.MongoRepository;

/**
 * Acceso a los eventos de comportamiento de los usuarios.
 */
public interface UserEventRepository extends MongoRepository<UserEvent, String> {

  /**
   * Borra todos los eventos de un usuario.
   *
   * @param userId identificador del usuario.
   */
  void deleteByUserId(String userId);
}
