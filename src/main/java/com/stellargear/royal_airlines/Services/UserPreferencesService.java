package com.stellargear.royal_airlines.Services;

import com.stellargear.royal_airlines.Models.DTOs.UserPreferencesRequest;
import com.stellargear.royal_airlines.Models.Entities.UserPreferences;
import com.stellargear.royal_airlines.Repositories.LocationRepository;
import com.stellargear.royal_airlines.Repositories.UserPreferencesRepository;
import com.stellargear.royal_airlines.Repositories.UserRepository;
import com.stellargear.royal_airlines.Utils.BadRequestException;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

/**
 * Guarda y valida las preferencias declaradas por el usuario.
 *
 * <p>Cada cambio invalida las recomendaciones precalculadas y, si el microservicio esta
 * configurado, pide su recalculo en background.</p>
 */
@Service
@RequiredArgsConstructor
public class UserPreferencesService {

  private static final int SCHEMA_VERSION = 1;

  /** Vocabulario controlado: igual a TravelInterest (Flutter) y a las claves de {@code Location.tags}. */
  private static final Set<String> INTERESTS = Set.of(
      "aventura", "cultura", "playa", "naturaleza", "gastronomia", "descanso", "ciudad", "nieve");
  private static final Set<String> STYLES = Set.of("economico", "equilibrado", "comodo", "premium");
  private static final Set<String> CLASSES = Set.of("economy", "premiumEconomy", "business", "first");
  private static final Set<String> COMPANY = Set.of("solo", "pareja", "familia", "amigos");

  private final UserPreferencesRepository repository;
  private final LocationRepository locationRepository;
  private final UserRepository userRepository;
  private final RecommendationService recommendationService;
  private final RecommenderClient recommenderClient;

  /**
   * Busca las preferencias de un usuario.
   *
   * @param userID identificador del usuario.
   * @return preferencias guardadas, o vacio si el usuario no las ha configurado.
   */
  public Optional<UserPreferences> find(String userID) {
    return repository.findById(userID);
  }

  /**
   * Crea o reemplaza las preferencias del usuario.
   *
   * @param userID identificador del usuario.
   * @param r preferencias ya validadas por el controlador.
   * @return preferencias guardadas.
   * @throws BadRequestException si algun valor no pertenece al vocabulario permitido.
   */
  public UserPreferences upsert(String userID, UserPreferencesRequest r) {
    validate(r);
    Instant now = Instant.now();
    Instant createdAt = repository.findById(userID).map(UserPreferences::createdAt).orElse(now);

    UserPreferences saved = new UserPreferences(
        userID, SCHEMA_VERSION,
        r.interests().stream().distinct().toList(),
        r.budgetMin() == null ? 0 : r.budgetMin(), r.budgetMax(), "COP",
        r.preferredMonths() == null ? List.of() : r.preferredMonths().stream().distinct().sorted().toList(),
        r.style(), r.preferredClass(), r.travelCompany(),
        r.tripDaysMin(), r.tripDaysMax(), r.flexibilityDays(),
        r.homeAirportCode() == null ? null : r.homeAirportCode().toUpperCase(),
        r.directFlightsOnly(),
        r.excludedLocationIds() == null ? List.of() : r.excludedLocationIds(),
        createdAt, now);
    UserPreferences persisted = repository.save(saved);

    // Completar el onboarding marca al usuario como listo para recibir recomendaciones.
    userRepository.findById(userID).ifPresent(user -> {
      if (!user.isOnboardingCompleted()) {
        user.setOnboardingCompleted(true);
        userRepository.save(user);
      }
    });

    refrescarRecomendaciones(userID);
    return persisted;
  }

  /**
   * Borra las preferencias de un usuario.
   *
   * @param userID identificador del usuario.
   */
  public void delete(String userID) {
    repository.deleteById(userID);
    refrescarRecomendaciones(userID);
  }

  /**
   * Deja las recomendaciones del usuario al día tras cambiar sus preferencias.
   *
   * <p>Borra su lista precalculada (que quedó con el perfil viejo) y, si el microservicio
   * está configurado, pide que la recalcule en background (la respuesta al usuario no espera).
   * Si Python no responde en su timeout no pasa nada: la app sirve {@code __popular__} hasta el
   * proximo job nocturno.</p>
   *
   * @param userID usuario cuyo perfil cambió.
   */
  private void refrescarRecomendaciones(String userID) {
    recommendationService.invalidateUser(userID);
    recommenderClient.recalcularUsuario(userID);
  }

  private void validate(UserPreferencesRequest r) {
    if (!INTERESTS.containsAll(r.interests())) bad("Interes no valido");
    if (r.budgetMin() != null && r.budgetMax() < r.budgetMin())
      bad("El presupuesto maximo debe ser mayor o igual al minimo");
    if (r.style() != null && !STYLES.contains(r.style())) bad("Estilo no valido");
    if (r.preferredClass() != null && !CLASSES.contains(r.preferredClass())) bad("Clase no valida");
    if (r.travelCompany() != null && !COMPANY.contains(r.travelCompany())) bad("Compania de viaje no valida");
    if (r.tripDaysMin() != null && r.tripDaysMax() != null && r.tripDaysMax() < r.tripDaysMin())
      bad("La duracion maxima debe ser mayor o igual a la minima");
    if (r.homeAirportCode() != null
        && locationRepository.findByIataCode(r.homeAirportCode().toUpperCase()) == null)
      bad("El aeropuerto base no existe");
  }

  private static void bad(String msg) {
    throw new BadRequestException(msg);
  }
}
