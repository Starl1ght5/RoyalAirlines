package com.stellargear.royal_airlines.Repositories;

import com.stellargear.royal_airlines.Models.Entities.Flight;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.data.mongodb.repository.Query;

import java.util.List;

/**
 * Acceso a la coleccion de vuelos.
 */
public interface FlightRepository extends MongoRepository<Flight, String> {

    /**
     * Busca los vuelos que llegan a un destino.
     *
     * <p>La lista de asientos se excluye de la proyeccion porque para listar vuelos solo se
     * necesitan los precios y las fechas.</p>
     *
     * @param arrivalID identificador del aeropuerto de llegada.
     * @return vuelos hacia ese destino.
     */
    @Query(value = "{ 'arrivalLocationID' : ?0 }", fields = "{ 'availableSeatIDs' : 0 }")
    List<Flight> searchFlightsForLocation(String arrivalID);

    /**
     * Busca un vuelo por su identificador.
     *
     * @param flightID identificador del vuelo.
     * @return vuelo encontrado o {@code null}.
     */
    @Query("{ 'flightID' : ?0 }")
    Flight searchByID(String flightID);
}