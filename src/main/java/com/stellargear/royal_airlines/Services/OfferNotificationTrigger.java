package com.stellargear.royal_airlines.Services;

import com.stellargear.royal_airlines.Models.Entities.Flight;
import com.stellargear.royal_airlines.Models.Events.FlightOfferCreatedEvent;
import com.stellargear.royal_airlines.Repositories.FlightRepository;
import java.time.LocalDateTime;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.event.EventListener;
import org.springframework.scheduling.annotation.Async;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import com.stellargear.royal_airlines.Models.Enums.FlightStatus;

/**
 * Dispara los avisos de oferta por dos vias: el evento al crear el vuelo (inmediato) y un job de
 * respaldo que recoge ofertas que el evento no cubrio (cargas directas a Mongo, fallos, push
 * apagado en ese momento). La deduplicacion por (userId, flightId) hace seguro que ambos
 * procesen el mismo vuelo.
 */
@Component
@RequiredArgsConstructor
public class OfferNotificationTrigger {

  private static final Logger logger = LoggerFactory.getLogger(OfferNotificationTrigger.class);

  private final FlightRepository flightRepository;
  private final OfferNotificationService notificationService;
  private final PushService pushService;

  /** Ofertas con {@code updatedAt} mas viejo que esto no las recoge el respaldo (evita rafagas por seeds antiguos). */
  @Value("${royal.push.backup-max-age-hours:24}")
  private long backupMaxAgeHours;

  /** Margen para que el evento normal procese primero. */
  @Value("${royal.push.backup-grace-minutes:2}")
  private long backupGraceMinutes;

  @Async
  @EventListener
  public void onFlightOfferCreated(FlightOfferCreatedEvent event) {
    flightRepository.findById(event.flightId()).ifPresent(this::process);
  }

  @Scheduled(cron = "${royal.push.backup-cron:0 */10 * * * *}", zone = "America/Bogota")
  public void backupSweep() {
    if (!pushService.isEnabled()) {
      return;
    }
    LocalDateTime now = LocalDateTime.now();
    List<Flight> pending = flightRepository
        .findByDiscountedTrueAndOfferNotifiedAtIsNullAndStatusAndUpdatedAtBetween(
            FlightStatus.ACTIVE, now.minusHours(backupMaxAgeHours), now.minusMinutes(backupGraceMinutes));

    if (!pending.isEmpty()) {
      logger.info("Respaldo de ofertas: {} vuelos pendientes de aviso", pending.size());
    }
    pending.forEach(this::process);
  }

  /** Procesa un vuelo y lo marca como notificado solo si se pudo evaluar de verdad. */
  private void process(Flight flight) {
    try {
      OfferNotificationService.Summary summary = notificationService.notifyOffer(flight);
      if (summary.processed()) {
        flight.setOfferNotifiedAt(LocalDateTime.now());
        flightRepository.save(flight);
      }
    } catch (RuntimeException error) {
      // Sin marcar: el respaldo lo reintenta en la proxima corrida.
      logger.warn("Fallo al procesar la oferta {}: {}", flight.getFlightID(), error.getMessage());
    }
  }
}
