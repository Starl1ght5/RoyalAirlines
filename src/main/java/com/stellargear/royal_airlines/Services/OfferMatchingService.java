package com.stellargear.royal_airlines.Services;

import com.stellargear.royal_airlines.Models.Entities.Flight;
import com.stellargear.royal_airlines.Models.Entities.Location;
import com.stellargear.royal_airlines.Models.Entities.UserPreferences;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.springframework.stereotype.Service;

/**
 * Decide si una oferta le sirve a un usuario segun sus preferencias de viaje.
 *
 * <p>Dos etapas: primero los <b>filtros duros</b> (si uno falla no hay coincidencia posible) y
 * despues un <b>puntaje de 0 a 1</b> con criterios blandos. Si a un usuario le falta un dato
 * blando (no puso meses, el destino no tiene {@code travelerFit}) ese criterio no cuenta ni a
 * favor ni en contra: su peso se reparte entre los demas. No toca la base de datos: recibe todo
 * ya cargado, por eso se prueba con objetos en memoria.</p>
 */
@Service
public class OfferMatchingService {

  static final double WEIGHT_INTERESTS = 0.40;
  static final double WEIGHT_MONTH = 0.25;
  static final double WEIGHT_COMPANY = 0.15;
  static final double WEIGHT_DISCOUNT = 0.20;

  /** Descuento de 50% o mas ya puntua 1.0 (mismo criterio que PromotionService). */
  static final double DISCOUNT_REFERENCE = 50.0;

  /** Margen sobre el presupuesto maximo: una oferta 10% arriba aun se considera dentro. */
  static final double BUDGET_TOLERANCE = 1.10;

  /** Puntaje del mes cuando solo cae dentro de la flexibilidad de fechas, no en el mes exacto. */
  static final double FLEXIBLE_MONTH_SCORE = 0.6;

  /**
   * Datos de la oferta ya resueltos, calculados una sola vez por vuelo y reutilizados con cada
   * usuario.
   *
   * @param flight vuelo en oferta.
   * @param origin aeropuerto de salida.
   * @param destination destino (con tags, bestMonths y travelerFit).
   * @param priceCop precio del pasaje en COP, en la misma moneda que el presupuesto.
   * @param discountPercent descuento en %.
   */
  public record OfferContext(Flight flight, Location origin, Location destination,
                             double priceCop, double discountPercent) {}

  /**
   * Resultado de una coincidencia.
   *
   * @param score puntaje de 0 a 1.
   * @param topInterest interes del usuario que mejor encaja con el destino (para el mensaje),
   *                    o {@code null} si ninguno puntua.
   */
  public record MatchResult(double score, String topInterest) {}

  /**
   * Evalua una oferta contra las preferencias de un usuario.
   *
   * @param offer oferta resuelta.
   * @param prefs preferencias del usuario.
   * @param userHomeLocationId aeropuerto base del perfil de usuario ({@code User.homeAirportID}),
   *                           usado solo si las preferencias no traen {@code homeAirportCode}.
   * @return el resultado, o vacio si algun filtro duro lo descarta.
   */
  public Optional<MatchResult> evaluate(OfferContext offer, UserPreferences prefs,
                                        String userHomeLocationId) {
    if (!passesHardFilters(offer, prefs, userHomeLocationId)) {
      return Optional.empty();
    }

    double weighted = 0;
    double totalWeight = 0;

    String topInterest = topInterest(prefs.interests(), offer.destination().getTags());
    double interests = interestsScore(prefs.interests(), offer.destination().getTags());
    weighted += WEIGHT_INTERESTS * interests;
    totalWeight += WEIGHT_INTERESTS;

    Double month = monthScore(offer.flight().getDepartureDate().toLocalDate(), prefs,
        offer.destination().getBestMonths());
    if (month != null) {
      weighted += WEIGHT_MONTH * month;
      totalWeight += WEIGHT_MONTH;
    }

    Double company = companyScore(prefs.travelCompany(), offer.destination().getTravelerFit());
    if (company != null) {
      weighted += WEIGHT_COMPANY * company;
      totalWeight += WEIGHT_COMPANY;
    }

    weighted += WEIGHT_DISCOUNT * Math.min(Math.max(offer.discountPercent(), 0), DISCOUNT_REFERENCE)
        / DISCOUNT_REFERENCE;
    totalWeight += WEIGHT_DISCOUNT;

    return Optional.of(new MatchResult(weighted / totalWeight, topInterest));
  }

  // ---------------------------------------------------------------- filtros duros

  static boolean passesHardFilters(OfferContext offer, UserPreferences prefs,
                                   String userHomeLocationId) {
    Flight flight = offer.flight();

    if (!matchesHomeAirport(offer.origin(), flight, prefs, userHomeLocationId)) {
      return false;
    }
    if (prefs.excludedLocationIds() != null
        && prefs.excludedLocationIds().contains(flight.getArrivalLocationID())) {
      return false;
    }
    if (Boolean.TRUE.equals(prefs.directFlightsOnly()) && !flight.isDirect()) {
      return false;
    }
    return offer.priceCop() >= prefs.budgetMin()
        && offer.priceCop() <= prefs.budgetMax() * BUDGET_TOLERANCE;
  }

  private static boolean matchesHomeAirport(Location origin, Flight flight, UserPreferences prefs,
                                            String userHomeLocationId) {
    if (prefs.homeAirportCode() != null && !prefs.homeAirportCode().isBlank()) {
      return origin != null && prefs.homeAirportCode().equalsIgnoreCase(origin.getIataCode());
    }
    // Sin aeropuerto base en las preferencias se usa el del perfil; sin ninguno, no hay como
    // saber desde donde viaja y no se le avisa (mejor callar que molestar con rutas ajenas).
    return userHomeLocationId != null && userHomeLocationId.equals(flight.getDepartureLocationID());
  }

  // ---------------------------------------------------------------- puntajes blandos

  /** Promedio de los intereses del usuario sobre los tags del destino (valores de 0 a 1). */
  static double interestsScore(List<String> interests, Map<String, Double> tags) {
    if (interests == null || interests.isEmpty() || tags == null || tags.isEmpty()) {
      return 0;
    }
    return interests.stream()
        .mapToDouble(interest -> clamp(tags.getOrDefault(interest, 0.0)))
        .average()
        .orElse(0);
  }

  /** Interes del usuario con el tag mas alto en el destino; {@code null} si ninguno puntua. */
  static String topInterest(List<String> interests, Map<String, Double> tags) {
    if (interests == null || tags == null) {
      return null;
    }
    return interests.stream()
        .filter(interest -> tags.getOrDefault(interest, 0.0) > 0)
        .max((a, b) -> Double.compare(tags.get(a), tags.get(b)))
        .orElse(null);
  }

  /**
   * Con meses preferidos: 1.0 si la salida cae en uno, 0.6 si solo cae dentro de
   * {@code flexibilityDays} de alguno y 0 si no. Sin meses preferidos usa la temporada del
   * destino (1.0 en temporada, 0.5 fuera). Sin ninguno de los dos datos: {@code null}.
   *
   * @param departure fecha de salida del vuelo.
   * @param prefs preferencias del usuario.
   * @param bestMonths meses recomendados del destino.
   * @return puntaje del mes, o {@code null} si no hay datos para puntuar.
   */
  static Double monthScore(LocalDate departure, UserPreferences prefs, List<Integer> bestMonths) {
    List<Integer> preferred = prefs.preferredMonths();

    if (preferred != null && !preferred.isEmpty()) {
      if (preferred.contains(departure.getMonthValue())) {
        return 1.0;
      }
      int flex = prefs.flexibilityDays() == null ? 0 : prefs.flexibilityDays();
      return flex > 0 && withinFlexibility(departure, preferred, flex) ? FLEXIBLE_MONTH_SCORE : 0.0;
    }
    if (bestMonths != null && !bestMonths.isEmpty()) {
      return bestMonths.contains(departure.getMonthValue()) ? 1.0 : 0.5;
    }
    return null;
  }

  private static boolean withinFlexibility(LocalDate date, List<Integer> months, int flexDays) {
    for (int year = date.getYear() - 1; year <= date.getYear() + 1; year++) {
      for (int month : months) {
        YearMonth ym = YearMonth.of(year, month);
        if (!date.isBefore(ym.atDay(1).minusDays(flexDays))
            && !date.isAfter(ym.atEndOfMonth().plusDays(flexDays))) {
          return true;
        }
      }
    }
    return false;
  }

  /** {@code travelerFit} del destino para la compania del usuario; {@code null} si no hay dato. */
  static Double companyScore(String company, Map<String, Double> travelerFit) {
    if (company == null || travelerFit == null || !travelerFit.containsKey(company)) {
      return null;
    }
    return clamp(travelerFit.get(company));
  }

  private static double clamp(Double value) {
    return value == null ? 0 : Math.min(Math.max(value, 0), 1);
  }
}
