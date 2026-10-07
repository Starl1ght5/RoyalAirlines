package com.stellargear.royal_airlines.Models.DTOs;

import org.joda.money.Money;

import java.util.ArrayList;

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
 * @param climate clima del destino.
 * @param bestDate mejor epoca para viajar.
 * @param activities actividades turisticas recomendadas.
 * @param rating calificacion del destino.
 */
public record LocationDTO(
        String locationID,
        String cityName,
        String countryName,
        String iataCode,
        String airportName,
        Money cheapestPrice,
        boolean featured,
        String climate,
        String bestDate,
        ArrayList<String> activities,
        double rating
) {}