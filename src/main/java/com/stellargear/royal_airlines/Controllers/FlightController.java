package com.stellargear.royal_airlines.Controllers;

import com.stellargear.royal_airlines.Models.DTOs.FlightDTO;
import com.stellargear.royal_airlines.Models.DTOs.SeatMapDTO;
import com.stellargear.royal_airlines.Services.FlightService;
import com.stellargear.royal_airlines.Services.SeatService;
import jakarta.validation.constraints.NotBlank;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.util.List;

/**
 * Expone las consultas publicas de vuelos: busqueda y mapa de asientos.
 *
 * <p>El alta de vuelos de prueba ya no esta aqui: vive en {@link InternalController}
 * ({@code POST /internal/flights/create}), protegida con {@code X-API-Key}.</p>
 */
@RestController
@RequiredArgsConstructor
@RequestMapping(path = "/api/v1/flights")
public class FlightController {

    private final FlightService flightService;
    private final SeatService seatService;

    /**
     * Busca los vuelos que llegan a un destino.
     *
     * @param destination codigo IATA del aeropuerto de llegada.
     * @return vuelos disponibles, vacios si el destino no tiene salidas.
     */
    @GetMapping(path = "/search")
    public List<FlightDTO> searchFlights(
            @RequestParam @NotBlank String destination,
            @RequestParam(required = false) String origin,
            @RequestParam(required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate departureDate,
            @RequestParam(required = false) Integer passengers) {
        return flightService.searchFlights(origin, destination, departureDate, passengers);
    }

    /**
     * Devuelve el mapa de asientos de un vuelo con precios y ocupados.
     *
     * @param flightID identificador del vuelo.
     */
    @GetMapping(path = "/{flightID}/seats")
    public SeatMapDTO getSeatMap(@PathVariable String flightID) {
        return seatService.getSeatMap(flightID);
    }

}
