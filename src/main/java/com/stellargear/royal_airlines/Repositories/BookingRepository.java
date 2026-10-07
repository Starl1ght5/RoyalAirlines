package com.stellargear.royal_airlines.Repositories;

import com.stellargear.royal_airlines.Models.Entities.Booking;
import com.stellargear.royal_airlines.Models.Enums.BookingStatus;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.data.mongodb.repository.Query;

import java.time.LocalDateTime;
import java.util.List;

/**
 * Acceso a la coleccion de reservas.
 */
public interface BookingRepository extends MongoRepository<Booking, String> {

    /**
     * Busca una reserva por su identificador.
     *
     * @param requestedID identificador de la reserva.
     * @return reserva encontrada o {@code null}.
     */
    @Query("{ 'bookingID' : ?0 }")
    Booking searchByID(String requestedID);

    /**
     * Localiza las reservas en un estado cuya fecha de creacion es anterior al limite dado.
     *
     * <p>Es la consulta que usa la tarea programada para expirar las reservas sin confirmar.</p>
     *
     * @param status estado que se busca, normalmente {@code PENDING}.
     * @param limit fecha limite de antiguedad.
     * @return reservas que cumplen ambas condiciones.
     */
    List<Booking> findByStatusAndBookingDateBefore(BookingStatus status, LocalDateTime limit);
}