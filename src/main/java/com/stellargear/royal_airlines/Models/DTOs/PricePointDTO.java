package com.stellargear.royal_airlines.Models.DTOs;

/**
 * Punto del historial de precios de una ruta para una fecha de salida.
 *
 * @param capturedDate dia en que se tomo la foto, en formato {@code yyyy-MM-dd}.
 * @param minPrice precio minimo observado ese dia, en dolares.
 * @param flightsCount numero de vuelos que alimentaron el punto.
 */
public record PricePointDTO(String capturedDate, double minPriceUsd, int flightsCount) {}
