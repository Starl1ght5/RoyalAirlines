package com.stellargear.royal_airlines.Models.Entities;

import com.stellargear.royal_airlines.Models.Enums.FlightStatus;
import lombok.Getter;
import lombok.Setter;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.LocalDateTime;
import java.util.List;

/**
 * Vuelo del catalogo con sus asientos y tarifas disponibles.
 */
@Setter
@Getter
@Document(collection = "Flights")
public class Flight {

    @Id
    private String flightID;

    private String airline;
    private double ticketPrice;
    private String flightNumber;

    private String departureLocationID;
    private String arrivalLocationID;

    private LocalDateTime departureDate;
    private LocalDateTime arrivalDate;

    private List<String> availableSeatIDs;
    private List<String> availableFeeIDs;

    private boolean discounted;
    private double discountPercentage;

    private FlightStatus status;

    /** Crea el vuelo vacio para que el servicio asigne sus campos. */
    public Flight() {}
}