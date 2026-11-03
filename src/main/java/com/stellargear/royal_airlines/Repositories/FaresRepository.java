package com.stellargear.royal_airlines.Repositories;

import com.stellargear.royal_airlines.Models.Entities.Fares;
import org.springframework.data.mongodb.repository.MongoRepository;

/**
 * Acceso a la coleccion de tarifas de pasaje.
 */
public interface FaresRepository extends MongoRepository<Fares, String> {

    /**
     * Busca una tarifa por su identificador.
     *
     * @param id identificador de la tarifa.
     * @return tarifa encontrada o {@code null}.
     */
    Fares findByFareID (String id);
}