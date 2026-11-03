package com.stellargear.royal_airlines.Models.Entities;

import com.stellargear.royal_airlines.Models.Enums.TravelClass;
import lombok.Getter;
import lombok.Setter;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.LocalDateTime;
import java.util.List;

/**
 * Tarifa de pasaje disponible para los vuelos.
 *
 * <p>El precio no se almacena: cada tarifa aplica un multiplicador sobre el precio del vuelo.</p>
 */
@Setter
@Getter
@Document(collection = "Fares")
public class Fares {

    /** Version del esquema con que se escribio el documento; 0 o ausente indica documento antiguo. */
    public static final int CURRENT_SCHEMA_VERSION = 1;

    @Id
    private String fareID;
    private TravelClass travelClass;
    private String tierName;
    private double priceDifference;

    /** Orden de la tarifa dentro de su clase; el servicio Python no debe adivinarlo por el nombre. */
    private int tierRank;

    /** Equipaje de bodega incluido en kilogramos; 0 significa ninguno. */
    private int checkedBagKg;

    /** Equipaje de mano incluido en kilogramos; 0 significa ninguno. */
    private int carryOnKg;

    /** Beneficios incluidos, solo para mostrar en pantalla; la logica usa los campos estructurados. */
    private List<String> benefits;

    /** Version del esquema con que se guardo este documento. */
    private int schemaVersion;

    /** Fecha de la ultima modificacion del documento. */
    private LocalDateTime updatedAt;

    /** Crea la tarifa vacia para que el catalogo la cargue directamente. */
    public Fares() {}
}
