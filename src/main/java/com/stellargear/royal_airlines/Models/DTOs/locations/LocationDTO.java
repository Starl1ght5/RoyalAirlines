package com.stellargear.royal_airlines.Models.DTOs.locations;

import com.stellargear.royal_airlines.Models.Enums.ClimateType;
import com.stellargear.royal_airlines.Models.Enums.VisaPolicy;
import org.joda.money.Money;

import java.util.List;
import java.util.Map;

/**
 * Vista de un destino lista para el cliente.
 *
 * @param locationID identificador del destino.
 * @param cityName ciudad del destino.
 * @param countryName pais del destino.
 * @param iataCode codigo IATA del aeropuerto.
 * @param airportName nombre del aeropuerto.
 * @param cheapestPrice vuelo mas barato hacia el destino, ya convertido a pesos colombianos.
 * @param featured indica si el destino aparece en la seccion de destacados.
 * @param rating calificacion del destino.
 * @param ratingCount numero de calificaciones recibidas; el modelo lo ignora mientras sea 0.
 * @param tags etiquetas turisticas con peso de 0.0 a 1.0.
 * @param travelerFit encaje con cada tipo de viajero, con peso de 0.0 a 1.0.
 * @param bestMonths meses recomendados, del 1 al 12.
 * @param bestDate meses recomendados en texto, derivado de {@code bestMonths}.
 * @param climateType clima normalizado.
 * @param climate clima en texto legible, derivado de {@code climateType}.
 * @param costLevel nivel de costo de vida, de 1 a 4.
 * @param visaPolicy requisitos de visa para pasaporte colombiano.
 * @param entryNote aviso al usuario sobre el control de entrada.
 * @param imageUrl imagen del destino para las tarjetas del front.
 */
public record LocationDTO(
        String locationID,
        String cityName,
        String countryName,
        String iataCode,
        String airportName,
        Money cheapestPrice,
        boolean featured,
        double rating,
        int ratingCount,
        Map<String, Double> tags,
        Map<String, Double> travelerFit,
        List<Integer> bestMonths,
        String bestDate,
        ClimateType climateType,
        String climate,
        int costLevel,
        VisaPolicy visaPolicy,
        String entryNote,
        String imageUrl
) {}
