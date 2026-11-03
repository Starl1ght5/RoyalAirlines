package com.stellargear.royal_airlines.Repositories;

import com.stellargear.royal_airlines.Models.Entities.Location;
import com.stellargear.royal_airlines.Models.Enums.LocationStatus;
import java.util.List;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.data.mongodb.repository.Query;

/**
 * Acceso a la coleccion de destinos.
 */
public interface LocationRepository extends MongoRepository<Location, String> {

    /**
     * Busca un destino por su identificador.
     *
     * @param locationID identificador del destino.
     * @return destino encontrado o {@code null}.
     */
    Location findByLocationID(String locationID);

    /**
     * Busca un destino por su codigo IATA.
     *
     * @param iataCode codigo IATA del aeropuerto.
     * @return destino encontrado o {@code null}.
     */
    Location findByIataCode(String iataCode);

    /**
     * Lista los destinos publicos de forma paginada.
     *
     * @param pageable pagina y cantidad solicitada.
     * @param status estado que deben tener los destinos.
     * @return pagina de destinos visibles.
     */
    Page<Location> findByStatus(Pageable pageable, LocationStatus status);

    /**
     * Lista de forma paginada los destinos publicos destacados.
     *
     * @param pageable pagina y cantidad solicitada.
     * @param status estado que deben tener los destinos.
     * @return pagina de destinos destacados.
     */
    Page<Location> findByStatusAndFeaturedTrue(Pageable pageable, LocationStatus status);

    /**
     * Lista TODOS los destinos con un estado dado (sin paginar). Lo usa el refresh
     * del featured dinamico para conocer el universo de destinos ACTIVE.
     *
     * @param status estado del destino.
     * @return destinos con ese estado.
     */
    List<Location> findByStatus(LocationStatus status);

    /**
     * Comprueba si ya existe un destino con los mismos datos.
     *
     * @param city ciudad del aeropuerto.
     * @param airport nombre del aeropuerto.
     * @param iataCode codigo IATA.
     * @return destino duplicado o {@code null} si no existe.
     */
    @Query("{ 'cityName' : ?0, 'airportName': ?1, 'iataCode': ?2 }")
    Location checkForExistingLocation(String city, String airport, String iataCode);
}