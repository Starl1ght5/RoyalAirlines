package com.stellargear.royal_airlines.Repositories;

import com.stellargear.royal_airlines.Models.Entities.Fee;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.data.mongodb.repository.Query;

/**
 * Acceso a la coleccion de tarifas de pasaje.
 */
public interface FeeRepository extends MongoRepository<Fee, String> {

    /**
     * Busca una tarifa por su identificador.
     *
     * @param requestedID identificador de la tarifa.
     * @return tarifa encontrada o {@code null}.
     */
    @Query("{ 'feeID' : ?0 }")
    Fee searchByID(String requestedID);
}