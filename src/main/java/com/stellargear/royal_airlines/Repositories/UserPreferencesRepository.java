package com.stellargear.royal_airlines.Repositories;

import com.stellargear.royal_airlines.Models.Entities.UserPreferences;
import org.springframework.data.mongodb.repository.MongoRepository;

/**
 * Acceso a las preferencias declaradas por los usuarios.
 */
public interface UserPreferencesRepository extends MongoRepository<UserPreferences, String> {}
