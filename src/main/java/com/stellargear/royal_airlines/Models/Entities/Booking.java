package com.stellargear.royal_airlines.Models.Entities;

import com.stellargear.royal_airlines.Models.Enums.BookingStatus;
import com.stellargear.royal_airlines.Models.Enums.CancelReason;
import com.stellargear.royal_airlines.Models.Enums.CompanionType;
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
 * datos que ya viven en sus propias colecciones. Los datos de origen y destino si se copian al
 * crear la reserva, porque el vuelo o el destino pueden cambiar despues y el historial debe
 * conservar lo que el usuario realmente reservo.</p>
 */
@Setter
@Getter
@Document(collection = "Booking")
public class Booking {

    /** Tipo de viaje de la reserva. */
    public enum TripType {
        ONE_WAY,
        ROUND_TRIP
    }

    /** Punto de la app desde el que el usuario llego a la reserva. */
    public enum BookingSource {
        /** Cliente que no informa el origen, incluidas reservas antiguas; no cuenta como busqueda manual. */
        UNKNOWN,
        MANUAL_SEARCH,
        RECOMMENDATION,
        HOME_OFFER,
        PROMOTION
    }

    @Id
    private String bookingID;
    private String userID;
    private String bookedFlightID;
    private List<String> bookedSeats;
    private String selectedFee;
    private LocalDateTime bookingDate;
    private double totalPrice;
    private int ticketCount;
    private BookingStatus status;

    /** Identificadores de origen y destino copiados desde el vuelo al reservar. */
    private String departureLocationID;
    private String arrivalLocationID;

    private String departureCountry;
    private String departureCity;
    private String arrivalCountry;
    private String arrivalCity;

    /** Dias entre la fecha de la reserva y la fecha de salida del vuelo. */
    private int leadTimeDays;

    private TripType tripType;

    /** Dias de estadia entre ida y regreso; {@code null} si el viaje es solo de ida. */
    private Integer stayDays;

    /** Compania con la que viaja; {@code null} si el usuario no lo indico en el checkout. */
    private CompanionType companionType;

    /** Edades de los pasajeros al momento de viajar. */
    private List<Integer> passengerAges;

    /** Nombre de la categoria de tarifa elegida, copiado de la tarifa al reservar. */
    private String fareTier;

    /** Extras contratados, por ejemplo {@code BAGGAGE_23KG} o {@code SEAT_EXTRA_LEGROOM}. */
    private List<String> extras;

    /**
     * Porcentaje por encima del pasaje mas barato disponible, al momento de reservar, en la misma
     * ruta; {@code null} si no se pudo calcular.
     */
    private Double pricePaidVsCheapestPct;

    /** Origen de la reserva dentro de la app. */
    private BookingSource source;

    /** Recomendacion que originó la reserva; {@code null} si no vino de una recomendacion. */
    private String recommendationID;

    /** Momento en que la reserva paso a CONFIRMED; {@code null} si nunca se confirmo. */
    private LocalDateTime confirmedAt;

    /** Momento en que la reserva paso a CANCELED; {@code null} si no se cancelo. */
    private LocalDateTime canceledAt;

    /** Quien cancelo la reserva; {@code null} mientras este confirmada o pendiente. */
    private CancelReason cancelReason;

    /** Calificacion del viaje dada por el usuario, de 1 a 5; la senal explicita de satisfaccion. */
    private Integer tripRating;

    /** Momento en que el usuario califico el viaje. */
    private LocalDateTime ratedAt;

    /** Version del esquema con que se escribio el documento; 0 o ausente indica documento antiguo. */
    public static final int CURRENT_SCHEMA_VERSION = 1;

    /** Version del esquema con que se guardo este documento. */
    private int schemaVersion;

    /** Fecha de la ultima modificacion del documento. */
    private LocalDateTime updatedAt;

    /** Crea la reserva vacia para que el servicio asigne sus campos. */
    public Booking() {}
}