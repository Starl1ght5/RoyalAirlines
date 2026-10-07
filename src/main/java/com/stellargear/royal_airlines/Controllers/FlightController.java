package com.stellargear.royal_airlines.Controllers;

import com.stellargear.royal_airlines.Models.DTOs.FlightDTO;
import com.stellargear.royal_airlines.Models.DTOs.SeatDTO;
import com.stellargear.royal_airlines.Services.FlightService;
import com.stellargear.royal_airlines.Services.InformationService;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Positive;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * Expone las consultas de vuelos y el alta de vuelos de prueba.
 */
@RestController
@RequiredArgsConstructor
@RequestMapping(path = "/api/v1/flights")
public class FlightController {

    private final InformationService informationService;
    private final FlightService flightService;

    /**
     * Crea un vuelo. Ruta reservada a ADMIN.
     *
     * @param airline nombre de la companhia aerea.
     * @param price precio base del pasaje en dolares.
     * @param depID identificador del aeropuerto de salida.
     * @param arrID identificador del aeropuerto de llegada.
     * @param flightNum numero de vuelo.
     * @return identificador del vuelo creado.
     */
    @PostMapping(path = "/debug/create")
    @ResponseStatus(HttpStatus.CREATED)
    public String createNewFlight(@RequestParam @NotBlank String airline,
                                  @RequestParam @Positive double price,
                                  @RequestParam @NotBlank String depID,
                                  @RequestParam @NotBlank String arrID,
                                  @RequestParam @NotBlank String flightNum) {
        return flightService.addNewFlight(airline, price, depID, arrID, flightNum);
    }

    /**
     * Busca los vuelos que llegan a un destino.
     *
     * @param destination codigo IATA del aeropuerto de llegada.
     * @return vuelos disponibles, vacios si el destino no tiene salidas.
     */
    @GetMapping(path = "/search")
    public List<FlightDTO> searchFlights(@RequestParam @NotBlank String destination) {
        return informationService.searchFlights(destination);
    }

    /**
     * Lista los asientos de un vuelo con su estado actual.
     *
     * @param flightID identificador del vuelo.
     * @return asientos del vuelo.
     */
    @GetMapping(path = "/seats/search")
    public List<SeatDTO> searchSeats(@RequestParam @NotBlank String flightID) {
        return informationService.getSeatsForFlight(flightID);
    }
}