package com.stellargear.royal_airlines.Models.Entities;

import java.time.Instant;
import java.util.List;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

/**
 * Preferencias DECLARADAS por el usuario. Un documento por usuario: {@code _id = userID}.
 * Lo inferido (arquetipo, afinidades) lo escribe Python en otra coleccion.
 * El presupuesto esta en COP, igual que la app (los precios de {@code Flight} se guardan en USD).
 *
 * @param userId identificador del usuario, usado tambien como {@code _id}.
 * @param schemaVersion version del esquema con que se guardo el documento.
 * @param interests intereses de viaje declarados.
 * @param budgetMin presupuesto minimo por viaje, en COP.
 * @param budgetMax presupuesto maximo por viaje, en COP.
 * @param currency moneda del presupuesto.
 * @param preferredMonths meses preferidos para viajar, del 1 al 12.
 * @param style estilo de viaje.
 * @param preferredClass clase de servicio preferida.
 * @param travelCompany compania con la que suele viajar.
 * @param tripDaysMin duracion minima del viaje en dias.
 * @param tripDaysMax duracion maxima del viaje en dias.
 * @param flexibilityDays margen de flexibilidad alrededor de los meses preferidos.
 * @param homeAirportCode codigo IATA del aeropuerto base.
 * @param directFlightsOnly indica si solo acepta vuelos directos.
 * @param excludedLocationIds destinos excluidos por el usuario.
 * @param createdAt momento en que se guardaron las preferencias.
 * @param updatedAt momento de la ultima actualizacion.
 */
@Document(collection = "UserPreferences")
public record UserPreferences(
    @Id String userId,
    int schemaVersion,
    List<String> interests,
    double budgetMin,
    double budgetMax,
    String currency,
    List<Integer> preferredMonths,
    String style,
    String preferredClass,
    String travelCompany,
    Integer tripDaysMin,
    Integer tripDaysMax,
    Integer flexibilityDays,
    String homeAirportCode,
    Boolean directFlightsOnly,
    List<String> excludedLocationIds,
    Instant createdAt,
    Instant updatedAt) {}
