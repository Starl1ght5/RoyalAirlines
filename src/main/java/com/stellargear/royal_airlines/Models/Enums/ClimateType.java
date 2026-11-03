package com.stellargear.royal_airlines.Models.Enums;

/**
 * Clima normalizado de un destino.
 */
public enum ClimateType {
    TROPICAL_HUMID("Tropical húmedo"),
    TROPICAL_DRY("Tropical seco"),
    SUBTROPICAL("Subtropical"),
    TEMPERATE("Templado"),
    HIGHLAND_COLD("Frío de montaña"),
    CONTINENTAL("Continental"),
    MEDITERRANEAN("Mediterráneo"),
    OCEANIC("Oceánico");

    private final String label;

    ClimateType(String label) {
        this.label = label;
    }

    public String getLabel() {
        return label;
    }
}