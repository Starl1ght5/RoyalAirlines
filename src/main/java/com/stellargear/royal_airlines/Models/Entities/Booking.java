package com.stellargear.royal_airlines.Models.Entities;

import com.stellargear.royal_airlines.Models.Enums.BookingStatus;
import lombok.Getter;
import lombok.Setter;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.LocalDateTime;
import java.util.List;

/**
 * Reserva de un vuelo con sus asientos y tarifa asociados.
 *
 * <p>Las referencias a vuelo, asientos y tarifa se guardan por identificador para evitar duplicar
 * datos que ya viven en sus propias colecciones.</p>
 */
@Setter
@Getter
@Document(collection = "Booking")
public class Booking {

    @Id
    private String bookingID;

    private String userID;
    private String userGender;
    private int userAge;

    private String bookedFlightID;
    private String departureCountry;
    private String departureCity;
    private String arrivalCountry;
    private String arrivalCity;

    private List<String> bookedSeatIDs;
    private String selectedFee;

    private LocalDateTime bookingDate;

    private double totalPrice;
    private int ticketCount;

    private BookingStatus status;

    /** Crea la reserva vacia para que el servicio asigne sus campos. */
    public Booking() {}
}