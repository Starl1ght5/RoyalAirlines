package com.stellargear.royal_airlines.Controllers;

import com.stellargear.royal_airlines.Models.DTOs.CreateLocationRequest;
import com.stellargear.royal_airlines.Models.DTOs.LocationDTO;
import com.stellargear.royal_airlines.Services.LocationService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Expone el catalogo de destinos y el alta de nuevos Aeropuertos.
 */
@RestController
@RequiredArgsConstructor
@RequestMapping(path = "/api/v1/locations")
public class LocationController {

    private final LocationService locationService;

    /**
     * Registra un destino nuevo. Ruta reservada a ADMIN.
     *
     * @param request ciudad, pais, codigo IATA y nombre del aeropuerto.
     */
    @PostMapping(path = "/debug/create")
    @ResponseStatus(HttpStatus.CREATED)
    public void createNewLocation(@Valid @RequestBody CreateLocationRequest request) {
        locationService.addNewLocation(request);
    }

    /**
     * Lista los destinos publicos, opcionalmente solo los destacados.
     *
     * @param page numero de pagina, empezando en cero.
     * @param size cantidad de destinos por pagina, con un maximo de 50 para evitar paginas gigantes.
     * @param featured indica si se filtran unicamente los destinos destacados.
     * @return pagina de destinos.
     */
    @GetMapping(path = "/")
    public Page<LocationDTO> searchLocations(@RequestParam(defaultValue = "0") @Min(0) int page,
                                             @RequestParam(defaultValue = "10") @Min(1) @Max(50) int size,
                                             @RequestParam(defaultValue = "false") boolean featured) {
        if (featured) {
            return locationService.getFeaturedLocations(page, size);
        }

        return locationService.getLocations(page, size);
    }
}