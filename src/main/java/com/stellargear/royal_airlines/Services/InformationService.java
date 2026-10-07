package com.stellargear.royal_airlines.Services;

import com.stellargear.royal_airlines.Models.DTOs.FlightDTO;
import com.stellargear.royal_airlines.Models.DTOs.SeatDTO;
import com.stellargear.royal_airlines.Models.Entities.Flight;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.List;

/**
 * Reune las consultas publicas del catalogo: vuelos por destino y asientos por vuelo.
 *
 * <p>Se separa de los servicios de dominio para que los controladores que exponen rutas publicas
 * no dependan directamente de la combinacion de varios repositorios.</p>
 */
@Service
@RequiredArgsConstructor
public class InformationService {

    private static final Logger logger = LoggerFactory.getLogger(InformationService.class);

    private final LocationService locationService;
    private final FlightService flightService;
    private final SeatService seatService;

    /**
     * Busca los vuelos que llegan a un destino.
     *
     * @param arrivalIataCode codigo IATA del aeropuerto de llegada.
     * @return vuelos del destino, lista vacia si no tiene ninguno.
     * @throws com.stellargear.royal_airlines.Utils.NotFoundException si el codigo IATA no existe.
     */
    public List<FlightDTO> searchFlights(String arrivalIataCode) {
        String locationID = locationService.searchByIataCode(arrivalIataCode);

        List<FlightDTO> flights = flightService.objectListToDto(flightService.searchFlightsForLocation(locationID));

        logger.info("Busqueda de vuelos hacia {}: {} resultados", arrivalIataCode, flights.size());
        return flights;
    }

    /**
     * Lista los asientos de un vuelo con su estado actual.
     *
     * @param flightID identificador del vuelo.
     * @return asientos del vuelo.
     * @throws com.stellargear.royal_airlines.Utils.NotFoundException si el vuelo no existe.
     */
    public List<SeatDTO> getSeatsForFlight(String flightID) {
        Flight flight = flightService.searchFlightByID(flightID);

        return seatService.searchAndConvertList(flight.getAvailableSeatIDs());
    }
}