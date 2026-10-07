package com.stellargear.royal_airlines.Services;

import com.stellargear.royal_airlines.Models.DTOs.FlightDTO;
import com.stellargear.royal_airlines.Models.Entities.Flight;
import com.stellargear.royal_airlines.Models.Enums.FlightStatus;
import com.stellargear.royal_airlines.Repositories.FlightRepository;
import com.stellargear.royal_airlines.Utils.MoneyExchange;
import com.stellargear.royal_airlines.Utils.NotFoundException;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.NoSuchElementException;

/**
 * Gestiona el alta de vuelos y su conversion a DTO.
 */
@Service
@RequiredArgsConstructor
public class FlightService {

    private static final Logger logger = LoggerFactory.getLogger(FlightService.class);

    private final FlightRepository flightRepository;
    private final LocationService locationService;
    private final SeatService seatService;
    private final MoneyExchange moneyExchange;
    private final FeeService feeService;

    /**
     * Crea un vuelo con sus asientos y todas las tarifas disponibles.
     *
     * @param airlineName nombre de la compania aerea.
     * @param price precio base del pasaje en dolares.
     * @param departureID identificador del aeropuerto de salida.
     * @param arrivalID identificador del aeropuerto de llegada.
     * @param flightNumber numero de vuelo.
     * @return identificador del vuelo creado.
     * @throws NotFoundException si alguno de los aeropuertos no existe.
     */
    public String addNewFlight(String airlineName, double price, String departureID, String arrivalID, String flightNumber) {
        locationService.searchByID(departureID);
        locationService.searchByID(arrivalID);

        Flight newFlight = new Flight();

        newFlight.setAirline(airlineName);
        newFlight.setTicketPrice(price);
        newFlight.setFlightNumber(flightNumber);
        newFlight.setDepartureLocationID(departureID);
        newFlight.setArrivalLocationID(arrivalID);
        newFlight.setDepartureDate(LocalDateTime.now());
        newFlight.setArrivalDate(LocalDateTime.now().plusHours(2));
        newFlight.setAvailableSeatIDs(seatService.generateSeats());
        newFlight.setAvailableFeeIDs(feeService.getFees());
        newFlight.setStatus(FlightStatus.ACTIVE);

        flightRepository.save(newFlight);

        logger.info("Vuelo creado, id: {} numero {}", newFlight.getFlightID(), flightNumber);
        return newFlight.getFlightID();
    }

    /**
     * Calcula la duracion de un trayecto en horas y minutos.
     *
     * @param start momento de salida.
     * @param finish momento de llegada.
     * @return duracion con el formato {@code Xh Ym}.
     */
    public String calculateTimeDifference(LocalDateTime start, LocalDateTime finish) {
        Duration timeBetween = Duration.between(start, finish);

        long hours = timeBetween.toHours() % 24;
        long minutes = timeBetween.toMinutes() % 60;

        return hours + "h " + minutes + "m";
    }

    /**
     * Devuelve el precio del vuelo mas barato que llega a un destino.
     *
     * @param locationForFlight identificador del aeropuerto de llegada.
     * @return precio del pasaje mas barato en dolares.
     * @throws NoSuchElementException si el destino no tiene ningun vuelo.
     */
    public double searchCheapestFromFlight(String locationForFlight) {
        List<Flight> flightsToSearch = flightRepository.searchFlightsForLocation(locationForFlight);
        return searchCheapestFromList(flightsToSearch).getTicketPrice();
    }

    /**
     * Selecciona el vuelo mas barato de una lista.
     *
     * @param listToSearch lista de vuelos a comparar.
     * @return vuelo con el precio mas bajo.
     * @throws NoSuchElementException si la lista esta vacia.
     */
    public Flight searchCheapestFromList(List<Flight> listToSearch) {
        return listToSearch.stream()
                .min(Comparator.comparingDouble(Flight::getTicketPrice))
                .orElseThrow(NoSuchElementException::new);
    }

    /**
     * Busca un vuelo por su identificador.
     *
     * @param requestedID identificador del vuelo.
     * @return vuelo encontrado.
     * @throws NotFoundException si el vuelo no existe.
     */
    public Flight searchFlightByID(String requestedID) {
        return flightRepository.findById(requestedID)
                .orElseThrow(() -> new NotFoundException("Vuelo no encontrado: " + requestedID));
    }

    /**
     * Lista los vuelos que llegan a un destino.
     *
     * @param locationID identificador del aeropuerto de llegada.
     * @return vuelos hacia ese destino.
     */
    public List<Flight> searchFlightsForLocation(String locationID) {
        return flightRepository.searchFlightsForLocation(locationID);
    }

    /**
     * Busca un vuelo y lo convierte a DTO.
     *
     * @param requestedID identificador del vuelo.
     * @return vuelo listo para serializar.
     * @throws NotFoundException si el vuelo no existe.
     */
    public FlightDTO searchAndConvertObject(String requestedID) {
        return objectToDto(searchFlightByID(requestedID));
    }

    /**
     * Convierte un vuelo de la base de datos en su version para el cliente.
     *
     * @param requestedObject vuelo de la base de datos.
     * @return vuelo con destinos, duracion y tarifas ya expandidos.
     */
    public FlightDTO objectToDto(Flight requestedObject) {
        return new FlightDTO(
                requestedObject.getFlightID(),
                requestedObject.getAirline(),
                moneyExchange.convertUSDtoCOP(requestedObject.getTicketPrice()),
                calculateTimeDifference(requestedObject.getDepartureDate(), requestedObject.getArrivalDate()),
                requestedObject.getFlightNumber(),
                locationService.findAndConvertObject(requestedObject.getDepartureLocationID()),
                locationService.findAndConvertObject(requestedObject.getArrivalLocationID()),
                requestedObject.getDepartureDate(),
                requestedObject.getArrivalDate(),
                null,
                feeService.searchAndConvertList(requestedObject.getAvailableFeeIDs(), requestedObject.getTicketPrice())
        );
    }

    /**
     * Convierte una lista de vuelos de la base de datos en DTO.
     *
     * @param requestedList vuelos a convertir.
     * @return lista de vuelos convertidos.
     */
    public List<FlightDTO> objectListToDto(List<Flight> requestedList) {
        List<FlightDTO> returnedList = new ArrayList<>();

        for (Flight flight : requestedList) {
            returnedList.add(objectToDto(flight));
        }

        return returnedList;
    }
}