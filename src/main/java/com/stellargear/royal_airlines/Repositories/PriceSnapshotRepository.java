package com.stellargear.royal_airlines.Repositories;

import com.stellargear.royal_airlines.Models.Entities.PriceSnapshot;
import java.util.List;
import java.util.Optional;
import org.springframework.data.mongodb.repository.MongoRepository;

/**
 * Acceso al historial de precios capturado por ruta y fecha.
 */
public interface PriceSnapshotRepository extends MongoRepository<PriceSnapshot, String> {

  List<PriceSnapshot> findByRouteKeyAndDepartureDateAndCapturedDateGreaterThanEqualOrderByCapturedDateAsc(
      String routeKey, String departureDate, String fromCapturedDate);

  Optional<PriceSnapshot>
      findFirstByDestinationIdAndCapturedDateGreaterThanEqualAndDepartureDateGreaterThanEqualOrderByMinPriceAsc(
          String destinationIata, String fromCapturedDate, String fromDepartureDate);
}
