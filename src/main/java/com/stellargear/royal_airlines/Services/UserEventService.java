package com.stellargear.royal_airlines.Services;

import com.stellargear.royal_airlines.Models.DTOs.EventBatchRequest;
import com.stellargear.royal_airlines.Models.DTOs.EventBatchRequest.EventDto;
import com.stellargear.royal_airlines.Models.Entities.User;
import com.stellargear.royal_airlines.Models.Entities.UserEvent;
import com.stellargear.royal_airlines.Repositories.UserEventRepository;
import com.stellargear.royal_airlines.Repositories.UserRepository;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class UserEventService {

  /** Tipos que el CLIENTE puede enviar. */
  private static final Set<String> CLIENT_TYPES = Set.of(
      "search", "destination_view", "flight_view", "flight_click", "checkout_start",
      "recommendation_impression", "recommendation_click", "recommendation_dismiss",
      "offer_impression", "offer_click");

  /*
   * Tipos que SOLO emite el servidor (miden conversion; si el cliente pudiera enviarlos se falsearian):
   * booking_created, booking_confirmed, booking_canceled, booking_abandoned,
   * favorite_add, favorite_remove, preferences_updated.
   */
  private static final int SCHEMA_VERSION = 1;
  private static final Duration MAX_PAST = Duration.ofDays(7);
  private static final Duration MAX_FUTURE = Duration.ofMinutes(5);
  private static final int MAX_VALUE_LEN = 200;

  private final UserEventRepository eventRepository;
  private final UserRepository userRepository;

  /** Opt-in: sin consentimiento explicito no se guarda nada. */
  public boolean trackingAllowed(String userID) {
    return userRepository.findById(userID).map(User::isConsentTracking).orElse(false);
  }

  /** Lote enviado por Flutter. */
  public EventBatchRequest.Result ingest(String userID, List<EventDto> events) {
    if (!trackingAllowed(userID)) {
      return new EventBatchRequest.Result(0, events.size(), false); // la app deja de enviar
    }
    Instant now = Instant.now();
    int accepted = 0;
    int rejected = 0;
    for (EventDto e : events) {
      if (!CLIENT_TYPES.contains(e.type()) || !payloadOk(e.payload())) {
        rejected++;
        continue;
      }
      UserEvent doc = new UserEvent(null, userID, e.clientEventId(), e.type(), clampTs(e.ts(), now), now,
          e.sessionId(), e.destinationId(), e.flightId(), null, e.recommendationId(),
          e.position(), e.context(), e.payload(), SCHEMA_VERSION);
      try {
        eventRepository.insert(doc);
        accepted++;
      } catch (DuplicateKeyException alreadyStored) {
        accepted++; // reintento de un lote que ya se guardo
      }
    }
    return new EventBatchRequest.Result(accepted, rejected, true);
  }

  /** Uso interno (BookingService, FavoriteService...). Respeta el consentimiento. */
  public void record(String userID, String type, String destinationId, String flightId,
      String bookingId, String context, Map<String, String> payload) {
    if (userID == null || !trackingAllowed(userID)) return;
    Instant now = Instant.now();
    eventRepository.insert(new UserEvent(null, userID, null, type, now, now, null, destinationId,
        flightId, bookingId, null, null, context, payload, SCHEMA_VERSION));
  }

  private static Instant clampTs(Instant ts, Instant now) {
    boolean tooOld = ts.isBefore(now.minus(MAX_PAST));
    boolean tooNew = ts.isAfter(now.plus(MAX_FUTURE));
    return (tooOld || tooNew) ? now : ts;
  }

  private static boolean payloadOk(Map<String, String> payload) {
    return payload == null
        || payload.values().stream().allMatch(v -> v == null || v.length() <= MAX_VALUE_LEN);
  }
}
