package com.stellargear.royal_airlines.Services;

import com.stellargear.royal_airlines.Models.Entities.Flight;
import com.stellargear.royal_airlines.Models.Entities.Location;
import com.stellargear.royal_airlines.Models.Entities.OfferNotification;
import com.stellargear.royal_airlines.Models.Entities.User;
import com.stellargear.royal_airlines.Models.Entities.UserPreferences;
import com.stellargear.royal_airlines.Models.Enums.FlightStatus;
import com.stellargear.royal_airlines.Repositories.LocationRepository;
import com.stellargear.royal_airlines.Repositories.OfferNotificationRepository;
import com.stellargear.royal_airlines.Repositories.UserPreferencesRepository;
import com.stellargear.royal_airlines.Repositories.UserRepository;
import com.stellargear.royal_airlines.Services.OfferMatchingService.MatchResult;
import com.stellargear.royal_airlines.Services.OfferMatchingService.OfferContext;
import com.stellargear.royal_airlines.Utils.MoneyExchange;
import java.text.NumberFormat;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.function.Function;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.stereotype.Service;

/**
 * Orquesta el aviso de una oferta: valida que el vuelo sea una oferta vigente, busca a los
 * usuarios a los que les sirve, respeta limites y deduplicacion y envia el push.
 *
 * <p>Se invoca desde el evento de creacion de vuelo y desde el job de respaldo (paso 1.5). Esta
 * clase no marca {@code Flight.offerNotifiedAt}: eso lo hace quien la llama cuando
 * {@link Summary#processed()} es true.</p>
 */
@Service
@RequiredArgsConstructor
public class OfferNotificationService {

  private static final Logger logger = LoggerFactory.getLogger(OfferNotificationService.class);
  private static final ZoneId ZONE = ZoneId.of("America/Bogota");
  private static final Locale LOCALE = Locale.forLanguageTag("es-CO");

  private final UserRepository userRepository;
  private final UserPreferencesRepository preferencesRepository;
  private final LocationRepository locationRepository;
  private final OfferNotificationRepository notificationRepository;
  private final DeviceTokenService deviceTokenService;
  private final OfferMatchingService matchingService;
  private final PushService pushService;
  private final MoneyExchange moneyExchange;

  @Value("${royal.push.match-threshold:0.6}")
  private double matchThreshold;

  @Value("${royal.push.max-per-user-per-day:2}")
  private int maxPerUserPerDay;

  /**
   * Resultado del procesamiento de un vuelo.
   *
   * @param processed false si no se pudo evaluar (push apagado o faltan datos): el vuelo debe
   *                  reintentarse despues y NO marcarse como notificado.
   * @param candidates usuarios con opt-in, preferencias y dispositivo que se evaluaron.
   * @param matched usuarios que superaron el umbral.
   * @param sent usuarios a los que llego el push.
   */
  public record Summary(boolean processed, int candidates, int matched, int sent) {
    static Summary notProcessed() { return new Summary(false, 0, 0, 0); }
    static Summary noOffer() { return new Summary(true, 0, 0, 0); }
  }

  /** Un vuelo es oferta si esta activo, vigente, futuro y con descuento minimo. */
  public boolean isOffer(Flight flight) {
    LocalDateTime now = LocalDateTime.now(); // misma zona que usa FlightService al guardar fechas
    return flight.getStatus() == FlightStatus.ACTIVE
        && PromotionService.discountPercent(flight) >= PromotionService.MIN_DISCOUNT_FOR_LABEL
        && (flight.getOfferValidUntil() == null || flight.getOfferValidUntil().isAfter(now))
        && flight.getDepartureDate() != null
        && flight.getDepartureDate().isAfter(now);
  }

  /**
   * Avisa de una oferta a los usuarios que coinciden.
   *
   * @param flight vuelo recien creado o actualizado.
   * @return resumen del procesamiento.
   */
  public Summary notifyOffer(Flight flight) {
    if (!pushService.isEnabled()) {
      return Summary.notProcessed();
    }
    if (!isOffer(flight)) {
      return Summary.noOffer();
    }

    Location origin = locationRepository.findByLocationID(flight.getDepartureLocationID());
    Location destination = locationRepository.findByLocationID(flight.getArrivalLocationID());
    if (origin == null || destination == null) {
      logger.warn("Oferta {} sin origen o destino resolvible; se omite", flight.getFlightID());
      return Summary.notProcessed();
    }

    double discount = PromotionService.discountPercent(flight);
    double priceCop = moneyExchange.convertUSDtoCOP(flight.getTicketPrice()).getAmount().doubleValue();
    OfferContext offer = new OfferContext(flight, origin, destination, priceCop, discount);

    List<User> users = userRepository.findByMarketingOptInTrue();
    List<String> userIds = users.stream().map(User::getUserID).toList();
    Map<String, UserPreferences> prefsByUser = preferencesRepository.findAllById(userIds).stream()
        .collect(Collectors.toMap(UserPreferences::userId, Function.identity()));
    Map<String, List<String>> tokensByUser = deviceTokenService.tokensByUser(userIds);
    Instant startOfDay = LocalDateTime.now(ZONE).toLocalDate().atStartOfDay(ZONE).toInstant();

    int candidates = 0;
    int matched = 0;
    int sent = 0;

    for (User user : users) {
      UserPreferences prefs = prefsByUser.get(user.getUserID());
      List<String> tokens = tokensByUser.get(user.getUserID());
      if (prefs == null || tokens == null || tokens.isEmpty()) {
        continue;
      }
      candidates++;

      if (notificationRepository.existsByUserIdAndFlightId(user.getUserID(), flight.getFlightID())) {
        continue;
      }
      if (notificationRepository.countByUserIdAndStatusAndSentAtAfter(
          user.getUserID(), OfferNotification.Status.SENT, startOfDay) >= maxPerUserPerDay) {
        continue;
      }

      Optional<MatchResult> match = matchingService.evaluate(offer, prefs, user.getHomeAirportID());
      if (match.isEmpty() || match.get().score() < matchThreshold) {
        continue;
      }
      matched++;

      if (deliver(user.getUserID(), tokens, offer, match.get())) {
        sent++;
      }
    }

    logger.info("Oferta {}: {} candidatos, {} coinciden, {} enviados",
        flight.getFlightID(), candidates, matched, sent);
    return new Summary(true, candidates, matched, sent);
  }

  /**
   * Reserva el registro de deduplicacion, envia el push y deja el estado final.
   *
   * @param userId destinatario.
   * @param tokens tokens FCM del usuario.
   * @param offer oferta evaluada.
   * @param match resultado de la coincidencia.
   * @return {@code true} si FCM entrego el mensaje a algun dispositivo.
   */
  private boolean deliver(String userId, List<String> tokens, OfferContext offer, MatchResult match) {
    Flight flight = offer.flight();
    OfferNotification reserved;
    try {
      reserved = notificationRepository.insert(new OfferNotification(
          null, userId, flight.getFlightID(), match.score(), Instant.now(),
          OfferNotification.Status.NO_DELIVERY));
    } catch (DuplicateKeyException alreadyNotified) {
      return false; // otro proceso (evento + job) se adelanto
    }

    int delivered = pushService.send(userId, tokens, title(offer), body(offer, match), data(offer));
    if (delivered > 0) {
      notificationRepository.save(new OfferNotification(
          reserved.id(), userId, flight.getFlightID(), match.score(), reserved.sentAt(),
          OfferNotification.Status.SENT));
      return true;
    }
    return false;
  }

  // ---------------------------------------------------------------- contenido del push

  static String title(OfferContext offer) {
    return "Oferta " + offer.origin().getCityName() + " → " + offer.destination().getCityName()
        + ": " + Math.round(offer.discountPercent()) + "% OFF";
  }

  static String body(OfferContext offer, MatchResult match) {
    String date = offer.flight().getDepartureDate().toLocalDate()
        .format(DateTimeFormatter.ofPattern("d 'de' MMM", LOCALE));
    String price = NumberFormat.getIntegerInstance(LOCALE).format(Math.round(offer.priceCop()));
    String base = "Sale el " + date + " desde $" + price + " COP.";
    return match.topInterest() == null
        ? base + " Coincide con tu perfil de viaje."
        : base + " Coincide con tu interés en " + match.topInterest() + ".";
  }

  /** Mismos campos que el slider de promociones usa para navegar a la busqueda. */
  static Map<String, String> data(OfferContext offer) {
    return Map.of(
        "type", "offer",
        "flightId", offer.flight().getFlightID(),
        "origin", offer.origin().getIataCode(),
        "destination", offer.destination().getIataCode(),
        "departureDate", offer.flight().getDepartureDate().toLocalDate().toString());
  }
}
