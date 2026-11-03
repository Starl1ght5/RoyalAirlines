package com.stellargear.royal_airlines.Models.DTOs;

import org.joda.money.Money;

import java.util.List;

/**
 * Mapa de asientos de un vuelo: distribucion, precios y codigos ocupados.
 *
 * @param flightID identificador del vuelo.
 * @param rows numero de filas de la cabina.
 * @param columns letras de las columnas, de izquierda a derecha.
 * @param categories zonas de la cabina con su rango de filas y precio en pesos colombianos.
 * @param extraLegroomRows filas con espacio extra.
 * @param takenSeats codigos ocupados o retenidos, por ejemplo {@code 12B}.
 * @param seatsLeft asientos libres.
 */
public record SeatMapDTO(
        String flightID,
        int rows,
        List<String> columns,
        List<CategoryDTO> categories,
        List<Integer> extraLegroomRows,
        List<String> takenSeats,
        int seatsLeft
) {
    /**
     * Zona de la cabina con su rango de filas y precio.
     *
     * @param category nombre de la categoria.
     * @param fromRow primera fila de la zona.
     * @param toRow ultima fila de la zona.
     * @param price precio del asiento en pesos colombianos.
     */
    public record CategoryDTO(String category, int fromRow, int toRow, Money price) {}
}
