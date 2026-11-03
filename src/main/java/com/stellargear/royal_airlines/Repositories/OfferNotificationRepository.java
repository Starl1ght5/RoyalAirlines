package com.stellargear.royal_airlines.Repositories;

import com.stellargear.royal_airlines.Models.Entities.OfferNotification;
import java.time.Instant;
import org.springframework.data.mongodb.repository.MongoRepository;

/**
 * Acceso al historial de avisos de oferta enviados.
 */
public interface OfferNotificationRepository extends MongoRepository<OfferNotification, String> {
  boolean existsByUserIdAndFlightId(String userId, String flightId);
  long countByUserIdAndStatusAndSentAtAfter(String userId, OfferNotification.Status status, Instant since);
}
