package com.stellargear.royal_airlines.Services;

import com.stellargear.royal_airlines.Models.DTOs.CreateLocationRequest;
import com.stellargear.royal_airlines.Models.DTOs.LocationDTO;
import com.stellargear.royal_airlines.Models.Entities.Location;
import com.stellargear.royal_airlines.Repositories.LocationRepository;
import com.stellargear.royal_airlines.Utils.ConflictException;
import com.stellargear.royal_airlines.Utils.MoneyExchange;
import com.stellargear.royal_airlines.Utils.NotFoundException;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;

/**
 * Gestiona el catalogo de destinos y su exposicion al cliente.
 */
@Service
@RequiredArgsConstructor
public class LocationService {

    private static final Logger logger = LoggerFactory.getLogger(LocationService.class);

    private final LocationRepository locationRepository;
    private final MoneyExchange moneyExchange;

    /**
     * Registra un destino nuevo.
     *
     * @param request datos del destino ya validados.
     * @throws ConflictException si ya existe un destino con los mismos datos.
     */
    public void addNewLocation(CreateLocationRequest request) {
        if (locationAlreadyPresent(request)) {
            throw new ConflictException("Este aeropuerto ya existe");
        }

        Location newLocation = new Location();
        newLocation.setAirportName(request.airportName());
        newLocation.setCityName(request.cityName());
        newLocation.setCountryName(request.countryName());
        newLocation.setIataCode(request.iataCode());

        locationRepository.save(newLocation);

        logger.info("Destino creado: {} ({})", request.cityName(), request.iataCode());
    }

    /**
     * Actualiza el precio minimo del destino, por ejemplo cuando cambia el vuelo mas barato.
     *
     * @param locationID identificador del destino.
     * @param cheapest nuevo precio minimo en dolares.
     */
    public void updateLocationCheapest(String locationID, double cheapest) {
        Location locationToUpdate = searchByID(locationID);

        if (locationToUpdate.getCheapestPrice() != cheapest) {
            locationToUpdate.setCheapestPrice(cheapest);
            locationRepository.save(locationToUpdate);

            logger.info("Precio minimo actualizado en {}: {}", locationToUpdate.getIataCode(), cheapest);
        }
    }

    /**
     * Busca un destino y lo convierte a DTO.
     *
     * @param requestedID identificador del destino.
     * @return destino listo para serializar.
     * @throws NotFoundException si el destino no existe.
     */
    public LocationDTO findAndConvertObject(String requestedID) {
        Location searchedObject = searchByID(requestedID);
        return objectToDto(searchedObject);
    }

    /**
     * Busca un destino por su identificador.
     *
     * @param requestedID identificador del destino.
     * @return destino encontrado.
     * @throws NotFoundException si el destino no existe.
     */
    public Location searchByID(String requestedID) {
        Location location = locationRepository.findByLocationID(requestedID);

        if (location == null) {
            throw new NotFoundException("Destino no encontrado: " + requestedID);
        }

        return location;
    }

    /**
     * Resuelve el identificador de un destino a partir de su codigo IATA.
     *
     * @param requestedCode codigo IATA del aeropuerto.
     * @return identificador interno del destino.
     * @throws NotFoundException si no existe ningun aeropuerto con ese codigo.
     */
    public String searchByIataCode(String requestedCode) {
        Location returnedLocation = locationRepository.findByIataCode(requestedCode);

        if (returnedLocation == null) {
            throw new NotFoundException("No existe un aeropuerto con el codigo " + requestedCode);
        }

        return returnedLocation.getLocationID();
    }

    /**
     * Lista los destinos publicos de forma paginada.
     *
     * @param page numero de pagina, empezando en cero.
     * @param size cantidad de destinos por pagina.
     * @return pagina de destinos visibles.
     */
    public Page<LocationDTO> getLocations(int page, int size) {
        Pageable pageable = PageRequest.of(page, size);
        Page<Location> locations = locationRepository.findBySecretFalse(pageable);

        return locations.map(this::objectToDto);
    }

    /**
     * Lista los destinos publicos destacados de forma paginada.
     *
     * @param page numero de pagina, empezando en cero.
     * @param size cantidad de destinos por pagina.
     * @return pagina de destinos destacados.
     */
    public Page<LocationDTO> getFeaturedLocations(int page, int size) {
        Pageable pageable = PageRequest.of(page, size);
        Page<Location> locations = locationRepository.findBySecretFalseAndFeaturedTrue(pageable);

        return locations.map(this::objectToDto);
    }

    /**
     * Comprueba si el destino ya esta registrado.
     *
     * @param infoToCheck datos del destino a verificar.
     * @return {@code true} si existe un destino con la misma ciudad, aeropuerto y codigo IATA.
     */
    public boolean locationAlreadyPresent(CreateLocationRequest infoToCheck) {
        return locationRepository.checkForExistingLocation(infoToCheck.cityName(), infoToCheck.airportName(), infoToCheck.iataCode()) != null;
    }

    /**
     * Convierte una lista de destinos de la base de datos en DTO.
     *
     * @param listToConvert destinos a convertir.
     * @return lista de destinos convertidos.
     */
    public List<LocationDTO> objectListToDto(List<Location> listToConvert) {
        List<LocationDTO> returnedList = new ArrayList<>();

        for (Location location : listToConvert) {
            returnedList.add(objectToDto(location));
        }

        return returnedList;
    }

    /**
     * Convierte un destino de la base de datos en su version para el cliente.
     *
     * @param requestedObject destino de la base de datos.
     * @return destino con el precio minimo ya convertido a pesos colombianos.
     */
    public LocationDTO objectToDto(Location requestedObject) {
        return new LocationDTO(
                requestedObject.getLocationID(),
                requestedObject.getCityName(),
                requestedObject.getCountryName(),
                requestedObject.getIataCode(),
                requestedObject.getAirportName(),
                moneyExchange.convertUSDtoCOP(requestedObject.getCheapestPrice()),
                requestedObject.isFeatured(),
                requestedObject.getClimate(),
                requestedObject.getBestDate(),
                requestedObject.getActivities(),
                requestedObject.getRating()
        );
    }
}