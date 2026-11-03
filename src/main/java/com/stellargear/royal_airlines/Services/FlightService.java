package com.stellargear.royal_airlines.Services;

import com.stellargear.royal_airlines.Models.DTOs.FlightDTO;
import com.stellargear.royal_airlines.Models.DTOs.locations.LocationDTO;
import com.stellargear.royal_airlines.Models.Entities.Fares;
import com.stellargear.royal_airlines.Models.Entities.Flight;
import com.stellargear.royal_airlines.Models.Events.FlightOfferCreatedEvent;
import com.stellargear.royal_airlines.Models.Enums.FlightStatus;
import com.stellargear.royal_airlines.Repositories.FlightRepository;
import com.stellargear.royal_airlines.Utils.BadRequestException;
import com.stellargear.royal_airlines.Utils.MoneyExchange;
import com.stellargear.royal_airlines.Utils.SeatCatalog;
import com.stellargear.royal_airlines.Utils.NotFoundException;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.*;

/**
 * Gestiona el alta de vuelos y su conversion a DTO.
 */
@Service
@RequiredArgsConstructor
public class FlightService {

    private static final Logger logger = LoggerFactory.getLogger(FlightService.class);

    private final FlightRepository flightRepository;
    private final LocationService locationService;
    private final MoneyExchange moneyExchange;
    private final FaresService faresService;
    private final MongoTemplate mongoTemplate;
    private final ApplicationEventPublisher eventPublisher;

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
        return addNewFlight(airlineName, price, departureID, arrivalID, flightNumber, null, null, null);
    }

    /**
     * Crea un vuelo y, si trae descuento, lo deja como oferta y publica el evento que dispara
     * los avisos push.
     *
     * @param airlineName nombre de la compania aerea.
     * @param price precio ORIGINAL del pasaje en dolares; si hay descuento, el precio de venta
     *              ({@code ticketPrice}) queda rebajado y este valor se guarda en {@code basePrice}.
     * @param departureID identificador del aeropuerto de salida.
     * @param arrivalID identificador del aeropuerto de llegada.
     * @param flightNumber numero de vuelo.
     * @param discountPercentage descuento entre 1 y 90 (opcional; null o 0 = sin oferta).
     * @param offerValidDays dias de vigencia de la oferta (opcional, 7 por defecto).
     * @param departureInDays dias hasta la salida (opcional: 7 si es oferta, 0 si no). Una oferta
     *                        con salida en el pasado no se notifica.
     * @return identificador del vuelo creado.
     * @throws NotFoundException si alguno de los aeropuertos no existe.
     */
    public String addNewFlight(String airlineName, double price, String departureID, String arrivalID,
                               String flightNumber, Double discountPercentage, Integer offerValidDays,
                               Integer departureInDays) {
        boolean isOffer = discountPercentage != null && discountPercentage > 0;
        if (isOffer && discountPercentage > 90) {
            throw new BadRequestException("El descuento debe estar entre 1 y 90");
        }

        locationService.searchByID(departureID);
        locationService.searchByID(arrivalID);

        Flight newFlight = new Flight();

        newFlight.setAirline(airlineName);
        newFlight.setTicketPrice(price);
        newFlight.setFlightNumber(flightNumber);
        newFlight.setDepartureLocationID(departureID);
        newFlight.setArrivalLocationID(arrivalID);
        LocalDateTime departure = LocalDateTime.now()
                .plusDays(departureInDays != null ? departureInDays : (isOffer ? 7 : 0));
        LocalDateTime arrival = departure.plusHours(2);

        newFlight.setDepartureDate(departure);
        newFlight.setArrivalDate(arrival);
        newFlight.setDurationMinutes((int) Duration.between(departure, arrival).toMinutes());
        newFlight.setBasePrice(price);
        newFlight.setSeatsLeft(SeatCatalog.CAPACITY);
        newFlight.setPriceUpdatedAt(LocalDateTime.now());
        newFlight.setSchemaVersion(Flight.CURRENT_SCHEMA_VERSION);
        newFlight.setUpdatedAt(LocalDateTime.now());
        newFlight.setAvailableFareIDs(faresService.getFees());
        newFlight.setStatus(FlightStatus.ACTIVE);

        if (isOffer) {
            newFlight.setDiscounted(true);
            newFlight.setDiscountPercentage(discountPercentage);
            newFlight.setBasePrice(price);
            newFlight.setTicketPrice(Math.round(price * (1 - discountPercentage / 100) * 100.0) / 100.0);
            newFlight.setOfferValidUntil(LocalDateTime.now().plusDays(offerValidDays != null ? offerValidDays : 7));
        }

        flightRepository.save(newFlight);

        if (isOffer) {
            // Los listeners son @Async: la respuesta al admin no espera los avisos.
            eventPublisher.publishEvent(new FlightOfferCreatedEvent(newFlight.getFlightID()));
        }

        logger.info("Vuelo creado, id: {} numero {}", newFlight.getFlightID(), flightNumber);
        return newFlight.getFlightID();
    }

    /**
     * Busca vuelos activos que llegan a un destino.
     *
     * @param origin codigo IATA de salida; {@code null} o vacio no filtra por origen.
     * @param destination codigo IATA de llegada.
     * @param departureDate dia de salida; {@code null} no filtra por fecha.
     * @param passengers numero minimo de asientos libres; {@code null} no filtra por cupo.
     * @return vuelos encontrados ya convertidos a DTO.
     */
    public List<FlightDTO> searchFlights(String origin, String destination,
                                         LocalDate departureDate, Integer passengers) {
        String arrivalID = locationService.searchByIataCode(destination);

        Criteria criteria = Criteria.where("arrivalLocationID").is(arrivalID)
                .and("status").is(FlightStatus.ACTIVE);

        if (origin != null && !origin.isBlank()) {
            criteria = criteria.and("departureLocationID")
                    .is(locationService.searchByIataCode(origin));
        }
        if (departureDate != null) {
            criteria = criteria.and("departureDate")
                    .gte(departureDate.atStartOfDay())
                    .lt(departureDate.plusDays(1).atStartOfDay());
        }
        if (passengers != null && passengers > 0) {
            criteria = criteria.and("seatsLeft").gte(passengers);
        }

        Query query = Query.query(criteria);
        query.fields().exclude("takenSeats");

        List<FlightDTO> flights = objectListToDto(mongoTemplate.find(query, Flight.class));

        logger.info("Busqueda de vuelos {} -> {} ({}): {} resultados",
                origin, destination, departureDate, flights.size());
        return flights;
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
                requestedObject.getAircraft(),
                locationService.findAndConvertObject(requestedObject.getDepartureLocationID()),
                locationService.findAndConvertObject(requestedObject.getArrivalLocationID()),
                requestedObject.getDepartureDate(),
                requestedObject.getArrivalDate(),
                requestedObject.getScales(),
                faresService.searchAndConvertList(requestedObject.getAvailableFareIDs(), requestedObject.getTicketPrice())
        );
    }

    /**
     * Convierte una lista de vuelos de la base de datos en DTO.
     *
     * @param requestedList vuelos a convertir.
     * @return lista de vuelos convertidos.
     */
    public List<FlightDTO> objectListToDto(List<Flight> requestedList) {
        Set<String> locationIDs = new HashSet<>();
        Set<String> fareIDs = new HashSet<>();

        for (Flight flight : requestedList) {
            locationIDs.add(flight.getDepartureLocationID());
            locationIDs.add(flight.getArrivalLocationID());
            if (flight.getAvailableFareIDs() != null) {
                fareIDs.addAll(flight.getAvailableFareIDs());
            }
        }

        Map<String, LocationDTO> locations = locationService.findAndConvertByIDs(locationIDs);
        Map<String, Fares> fares = faresService.loadByIDs(fareIDs);

        List<FlightDTO> returnedList = new ArrayList<>();
        for (Flight flight : requestedList) {
            returnedList.add(new FlightDTO(
                    flight.getFlightID(),
                    flight.getAirline(),
                    moneyExchange.convertUSDtoCOP(flight.getTicketPrice()),
                    calculateTimeDifference(flight.getDepartureDate(), flight.getArrivalDate()),
                    flight.getFlightNumber(),
                    flight.getAircraft(),
                    locations.get(flight.getDepartureLocationID()),
                    locations.get(flight.getArrivalLocationID()),
                    flight.getDepartureDate(),
                    flight.getArrivalDate(),
                    flight.getScales(),
                    faresService.convertList(flight.getAvailableFareIDs(), fares, flight.getTicketPrice())
            ));
        }
        return returnedList;
    }
}