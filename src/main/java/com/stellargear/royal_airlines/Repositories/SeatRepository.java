package com.stellargear.royal_airlines.Repositories;

import com.stellargear.royal_airlines.Models.Entities.Seat;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.data.mongodb.repository.Query;

/**
 * Acceso a la coleccion de asientos.
 */
public interface SeatRepository extends MongoRepository<Seat, String> {

    /**
     * Busca un asiento por su identificador.
     *
     * @param requestedID identificador del asiento.
     * @return asiento encontrado o {@code null}.
     */
    @Query("{ 'seatID' : ?0 }")
    Seat searchByID(String requestedID);
}