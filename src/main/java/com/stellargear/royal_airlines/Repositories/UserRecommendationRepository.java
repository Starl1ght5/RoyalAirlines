package com.stellargear.royal_airlines.Repositories;

import com.stellargear.royal_airlines.Models.Entities.UserRecommendation;
import org.springframework.data.mongodb.repository.MongoRepository;

/**
 * Acceso a las recomendaciones precalculadas por el microservicio Python.
 */
public interface UserRecommendationRepository extends MongoRepository<UserRecommendation, String> {
}
