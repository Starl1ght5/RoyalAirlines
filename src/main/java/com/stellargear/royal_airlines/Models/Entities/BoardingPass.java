package com.stellargear.royal_airlines.Models.Entities;

import com.stellargear.royal_airlines.Models.Enums.BoardingPassStatus;
import lombok.Getter;
import lombok.Setter;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.LocalDateTime;
import java.util.List;

/**
 * Pase de aboardar emitido al confirmar una reserva.
 *
 * <p>Guarda una copia de los datos del vuelo y del asiento para que el pase pueda mostrarse sin
 * volver a consultar reservas, vuelos ni tarifas.</p>
 */
@Setter
@Getter
@Document(collection = "BoardingPass")
public class BoardingPass {

    @Id
    private String boardingPassID;

    private String bookedUserID;
    private List<String> bookedSeatIDs;
    private String bookedFlightID;

    private String passengerInfo;
    private List<String> seats;
    private String seatClass;

    private String gate;
    private String group;
    private String flightNumber;
    private String airline;
    private String departureIataCode;
    private String arrivalIataCode;
    private LocalDateTime departureDate;

    public BoardingPassStatus status;

    /** Crea el pase sin datos, todos los campos se asignan despues mediante sus setters. */
    public BoardingPass() {}
}