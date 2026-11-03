package com.stellargear.royal_airlines.Models.DTOs;

import jakarta.validation.constraints.*;
import java.util.List;

/**
 * Cuerpo del PUT de preferencias. Las claves base coinciden con
 * {@code TravelerPreferencesModel.toJson()} de Flutter.
 *
 * @param interests intereses de viaje, hasta ocho.
 * @param budgetMin presupuesto minimo por viaje, en COP.
 * @param budgetMax presupuesto maximo por viaje, en COP.
 * @param preferredMonths meses preferidos para viajar, del 1 al 12.
 * @param style estilo de viaje.
 * @param preferredClass clase de servicio preferida.
 * @param travelCompany compania con la que suele viajar.
 * @param tripDaysMin duracion minima del viaje en dias.
 * @param tripDaysMax duracion maxima del viaje en dias.
 * @param flexibilityDays margen de flexibilidad en dias alrededor de los meses preferidos.
 * @param homeAirportCode codigo IATA del aeropuerto base.
 * @param directFlightsOnly indica si solo acepta vuelos directos.
 * @param excludedLocationIds destinos que el usuario no quiere ver.
 */
public record UserPreferencesRequest(
    @NotEmpty @Size(max = 8) List<String> interests,
    @PositiveOrZero Double budgetMin,
    @NotNull @Positive Double budgetMax,
    @Size(max = 12) List<@Min(1) @Max(12) Integer> preferredMonths,
    String style,
    String preferredClass,
    String travelCompany,
    @Min(1) @Max(90) Integer tripDaysMin,
    @Min(1) @Max(90) Integer tripDaysMax,
    @Min(0) @Max(30) Integer flexibilityDays,
    @Size(max = 3) String homeAirportCode,
    Boolean directFlightsOnly,
    @Size(max = 100) List<String> excludedLocationIds) {}
