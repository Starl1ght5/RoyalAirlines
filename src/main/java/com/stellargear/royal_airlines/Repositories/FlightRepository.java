package com.stellargear.royal_airlines.Repositories;

import com.stellargear.royal_airlines.Models.Entities.Flight;
import com.stellargear.royal_airlines.Models.Enums.FlightStatus;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.data.mongodb.repository.Query;

import java.time.LocalDateTime;
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

    /**
     * Vuelos con un estado dado y salida en el intervalo {@code [from, to)}.
     *
     * <p>Los usa el job de {@code PriceSnapshots}.</p>
     *
     * @param status estado del vuelo.
     * @param from inicio del intervalo de salida, inclusive.
     * @param to fin del intervalo de salida, exclusivo.
     * @return vuelos que cumplen las condiciones.
     */
    List<Flight> findByStatusAndDepartureDateBetween(FlightStatus status, LocalDateTime from, LocalDateTime to);

    /**
     * Ofertas pendientes de aviso push, para el job de respaldo.
     *
     * @param status estado del vuelo (ACTIVE).
     * @param from limite inferior de {@code updatedAt}: ignora ofertas viejas (seeds antiguos).
     * @param to limite superior de {@code updatedAt}: deja pasar al evento normal primero.
     */
    List<Flight> findByDiscountedTrueAndOfferNotifiedAtIsNullAndStatusAndUpdatedAtBetween(
            FlightStatus status, LocalDateTime from, LocalDateTime to);
}