package com.stellargear.royal_airlines.Models.Entities;

import com.stellargear.royal_airlines.Models.Enums.FlightStatus;
import lombok.Getter;
import lombok.Setter;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.LocalDateTime;
import java.util.ArrayList;
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
    private String aircraft;
    private int scales;
    private String departureLocationID;
    private String arrivalLocationID;
    private LocalDateTime departureDate;
    private LocalDateTime arrivalDate;
    private List<String> availableFareIDs;
    private boolean discounted;
    private double discountPercentage;
    private FlightStatus status;
    private double basePrice;
    private int durationMinutes;
    private int seatsLeft;
    private List<String> takenSeats = new ArrayList<>();
    private LocalDateTime offerValidUntil;
    /** Cuando se proceso el aviso de oferta (push). {@code null} = pendiente. */
    private LocalDateTime offerNotifiedAt;
    private LocalDateTime priceUpdatedAt;
    public static final int CURRENT_SCHEMA_VERSION = 1;
    private int schemaVersion;
    private LocalDateTime updatedAt;
    public boolean isDirect() {
        return scales == 0;
    }
    public Flight() {}
}