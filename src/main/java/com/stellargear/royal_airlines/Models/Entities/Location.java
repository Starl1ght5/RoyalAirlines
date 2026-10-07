package com.stellargear.royal_airlines.Models.Entities;

import lombok.Getter;
import lombok.Setter;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

import java.util.ArrayList;

/**
 * Destino turistico servido por la aerolinea.
 *
 * <p>Los destinos marcados como secretos quedan ocultos del catalogo publico y solo se usan
 * desde las operaciones internas de la aplicacion.</p>
 */
@Setter
@Getter
@Document(collection = "Destinations")
public class Location {

    @Id
    private String locationID;

    private String cityName;
    private String countryName;
    private String iataCode;
    private double cheapestPrice;
    private String airportName;
    private boolean featured;
    private String climate;
    private String bestDate;
    private ArrayList<String> activities;
    private double rating;
    private boolean secret;

    /** Crea el destino vacio para que el servicio asigne sus campos. */
    public Location() {}
}