package com.stellargear.royal_airlines.Models.Entities;

import lombok.Getter;
import lombok.Setter;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

/**
 * Tarifa deassage disponible para los vuelos.
 *
 * <p>El precio no se almacena: cada tarifa aplica un multiplicador sobre el precio del vuelo.</p>
 */
@Setter
@Getter
@Document(collection = "Fees")
public class Fee {

    @Id
    private String feeID;

    private String feeName;
    private double priceDifference;

    /** Crea la tarifa vacia para que el catalogo la cargue directamente. */
    public Fee() {}
}