package com.stellargear.royal_airlines.Controllers;

import com.stellargear.royal_airlines.Models.DTOs.locations.LocationDTO;
import com.stellargear.royal_airlines.Services.LocationService;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Expone el catalogo publico de destinos.
 */
@RestController
@RequiredArgsConstructor
@RequestMapping(path = "/api/v1/locations")
public class LocationController {

    private final LocationService locationService;
    private static final Logger logger = LoggerFactory.getLogger(LocationService.class);

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

        logger.info("Retornados los destinos: {}", featured);
        return locationService.getLocations(page, size);
    }
}