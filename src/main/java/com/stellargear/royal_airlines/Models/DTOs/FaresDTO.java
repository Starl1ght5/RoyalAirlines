package com.stellargear.royal_airlines.Models.DTOs;

import com.stellargear.royal_airlines.Models.Enums.TravelClass;
import org.joda.money.Money;

import java.util.List;

/**
 * Vista de una tarifa de pasaje, usada tambien como cuerpo de creacion en el panel de admin.
 *
 * @param feeID identificador de la tarifa.
 * @param travelClass clase de servicio; viaja como cadena exacta para el servicio Python.
 * @param tierName nombre comercial de la tarifa.
 * @param priceDifference multiplicador aplicado sobre el precio del pasaje.
 * @param tierRank orden de la tarifa dentro de su clase.
 * @param checkedBagKg equipaje de bodega incluido en kilogramos.
 * @param carryOnKg equipaje de mano incluido en kilogramos.
 * @param benefits beneficios incluidos en la tarifa (solo presentacion).
 * @param price de la tarifa ya convertido a pesos colombianos, o nulo cuando no aplica.
 */
public record FaresDTO(
        String feeID,
        TravelClass travelClass,
        String tierName,
        double priceDifference,
        int tierRank,
        int checkedBagKg,
        int carryOnKg,
        List<String> benefits,
        Money price
) {}
