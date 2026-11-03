package com.stellargear.royal_airlines.Utils;

import org.joda.money.CurrencyUnit;
import org.joda.money.Money;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;

/**
 * Convierte importes entre dolares y pesos colombianos.
 *
 * <p>Los precios se guardan en dolares porque las tarifas y los asientos se definen en esa moneda,
 * y se entregan al cliente ya convertidos.</p>
 */
@Service
public class MoneyExchange {

    /** Tasa de cambio fija usada para las conversiones. */
    private static final BigDecimal COP_EXCHANGE_RATE = new BigDecimal("4000.00");

    /**
     * Convierte un importe de dolares a pesos colombianos.
     *
     * @param usdValue importe en dolares.
     * @return importe equivalente en pesos colombianos, truncado a la precision de la moneda.
     */
    public Money convertUSDtoCOP(double usdValue) {
        Money usd = Money.of(CurrencyUnit.USD, usdValue);
        return usd.convertedTo(CurrencyUnit.of("COP"), COP_EXCHANGE_RATE, RoundingMode.DOWN);
    }

    /**
     * Calcula el precio de una tarifa sobre el precio base de un pasaje.
     *
     * @param fees multiplicador de la tarifa.
     * @param basePrice precio del pasaje en dolares.
     * @return resultado del pasaje ajustado por la tarifa, ya en pesos colombianos.
     */
    public Money calculateFees(double fees, double basePrice) {
        Money amount = Money.of(CurrencyUnit.USD, basePrice);
        Money totalPrice = amount.multipliedBy(fees, RoundingMode.DOWN);
        return totalPrice.convertedTo(CurrencyUnit.of("COP"), COP_EXCHANGE_RATE, RoundingMode.DOWN);
    }
}
