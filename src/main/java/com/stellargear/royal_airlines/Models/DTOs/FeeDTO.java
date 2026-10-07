package com.stellargear.royal_airlines.Models.DTOs;

import org.joda.money.Money;

/**
 * Vista de una tarifa deassage.
 *
 * @param feeID identificador de la tarifa.
 * @param feeName nombre comercial de la tarifa.
 * @param priceDifference multiplicador aplicado sobre el precio del pasaje.
 * @param precio de la tarifa ya convertido a pesos colombianos, o nulo cuando no aplica.
 */
public record FeeDTO(
        String feeID,
        String feeName,
        double priceDifference,
        Money price
) {}