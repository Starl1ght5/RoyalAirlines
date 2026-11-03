package com.stellargear.royal_airlines.Services;

import com.stellargear.royal_airlines.Models.DTOs.locations.LocationCreationDTO;
import com.stellargear.royal_airlines.Models.DTOs.locations.LocationDTO;
import com.stellargear.royal_airlines.Models.Entities.Flight;
import com.stellargear.royal_airlines.Models.Entities.Location;
import com.stellargear.royal_airlines.Models.Enums.ClimateType;
import com.stellargear.royal_airlines.Models.Enums.LocationStatus;
import com.stellargear.royal_airlines.Repositories.FlightRepository;
import com.stellargear.royal_airlines.Repositories.LocationRepository;
import com.stellargear.royal_airlines.Utils.MoneyExchange;
import com.stellargear.royal_airlines.Utils.NotFoundException;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;

import java.text.Normalizer;
import java.time.LocalDateTime;
import java.time.Month;
import java.time.format.TextStyle;
import java.util.*;

import java.util.stream.Collectors;

/**
 * Gestiona el catalogo de destinos, su exposicion al cliente y la actualizacion periodica
 * de su precio minimo.
 */
@Service
@RequiredArgsConstructor
public class LocationService {

    private static final Logger logger = LoggerFactory.getLogger(LocationService.class);

    private final LocationRepository locationRepository;
    private final FlightRepository flightRepository;
    private final MoneyExchange moneyExchange;
    private final MongoTemplate mongoTemplate;

    /**
     * Registra un destino nuevo.
     *
     * @param request datos del destino ya validados.
     * @return {@code 201 Created} si se guardo, o {@code 409 Conflict} si ya existia.
     */
    public ResponseEntity<?> addNewLocation(LocationCreationDTO request) {
        if (locationAlreadyPresent(request)) {
            return new ResponseEntity<>(HttpStatus.CONFLICT);
        }

        Location newLocation = new Location();
        newLocation.setAirportName(request.airportName());
        newLocation.setCityName(request.cityName());
        newLocation.setCountryName(request.countryName());
        newLocation.setIataCode(request.iataCode());
        newLocation.setTags(normalizeTags(request.tags()));
        newLocation.setTravelerFit(request.travelerFit() == null ? Map.of() : normalizeTags(request.travelerFit()));
        newLocation.setBestMonths(request.bestMonths().stream().distinct().sorted().toList());
        newLocation.setClimateType(request.climateType());
        newLocation.setCostLevel(request.costLevel());
        newLocation.setVisaPolicy(request.visaPolicy());
        newLocation.setEntryNote(request.entryNote());
        newLocation.setRatingCount(request.ratingCount());
        newLocation.setImageUrl(request.imageUrl());
        newLocation.setSchemaVersion(Location.CURRENT_SCHEMA_VERSION);
        newLocation.setUpdatedAt(LocalDateTime.now());
        newLocation.setCheapestPrice(40);
        newLocation.setStatus(LocationStatus.ACTIVE);
        newLocation.setFeatured(false);
        newLocation.setRating(3.0);

        locationRepository.save(newLocation);

        logger.info("Destino creado: {} ({})", request.cityName(), request.iataCode());
        return new ResponseEntity<>(HttpStatus.CREATED);
    }

    /**
     * Busca varios destinos y los convierte a DTO en una sola consulta.
     *
     * @param ids identificadores de los destinos.
     * @return mapa de identificador a destino convertido.
     */
    public Map<String, LocationDTO> findAndConvertByIDs(Collection<String> ids) {
        return locationRepository.findAllById(ids).stream()
                .collect(Collectors.toMap(Location::getLocationID, this::objectToDto));
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
            mongoTemplate.updateFirst(
                    Query.query(Criteria.where("locationID").is(locationID)),
                    Update.update("cheapestPrice", cheapest),
                    Location.class);

            logger.info("Precio minimo actualizado en {}: {}", locationToUpdate.getIataCode(), cheapest);
        }
    }

    /**
     * Refresca el precio minimo de todos los destinos a partir de sus vuelos.
     *
     * <p>Se ejecuta cada diez minutos en segundo plano. El precio minimo de un destino es el
     * pasaje mas barato entre todos los vuelos que llegan a el; los destinos sin vuelos
     * conservan el precio que ya tenian.</p>
     */
    @Scheduled(fixedDelay = 600_000)
    public void updateAllCheapestPrices() {
        Map<String, Double> cheapestPerLocation = new HashMap<>();

        for (Flight flight : flightRepository.findAll()) {
            cheapestPerLocation.merge(flight.getArrivalLocationID(), flight.getTicketPrice(), Math::min);
        }

        int refreshedCount = 0;

        for (Location location : locationRepository.findAll()) {
            Double cheapest = cheapestPerLocation.get(location.getLocationID());

            if (cheapest != null) {
                updateLocationCheapest(location.getLocationID(), cheapest);
                refreshedCount++;
            }
        }

        logger.info("Precios minimos refrescados: {} destinos con vuelos", refreshedCount);
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
        Page<Location> locations = locationRepository.findByStatus(pageable, LocationStatus.ACTIVE);

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
        Page<Location> locations = locationRepository.findByStatusAndFeaturedTrue(pageable, LocationStatus.ACTIVE);

        return locations.map(this::objectToDto);
    }

    /**
     * Comprueba si el destino ya esta registrado.
     *
     * @param infoToCheck datos del destino a verificar.
     * @return {@code true} si existe un destino con la misma ciudad, aeropuerto y codigo IATA.
     */
    public boolean locationAlreadyPresent(LocationCreationDTO infoToCheck) {
        return locationRepository.checkForExistingLocation(infoToCheck.cityName(), infoToCheck.airportName(), infoToCheck.iataCode()) != null;
    }

    /**
     * Normaliza las llaves de las etiquetas: minusculas, sin tildes ni espacios, y sin los
     * caracteres que MongoDB no admite en una llave. Asi "Gastronomía" y "gastronomia" son la misma.
     */
    private Map<String, Double> normalizeTags(Map<String, Double> rawTags) {
        Map<String, Double> clean = new LinkedHashMap<>();

        for (Map.Entry<String, Double> entry : rawTags.entrySet()) {
            String key = Normalizer.normalize(entry.getKey().trim().toLowerCase(Locale.ROOT), Normalizer.Form.NFD)
                    .replaceAll("\\p{M}", "")
                    .replaceAll("[\\s.$]+", "_");

            if (!key.isEmpty() && entry.getValue() != null) {
                clean.merge(key, entry.getValue(), Math::max);
            }
        }

        return clean;
    }

    /**
     * Convierte una lista de meses en texto con tramos, por ejemplo [12,1,2,3,6,7,8] en
     * "Junio - Agosto, Diciembre - Marzo". Los tramos pueden cruzar de diciembre a enero.
     */
    private String monthsToText(List<Integer> months) {
        if (months == null || months.isEmpty()) {
            return "";
        }

        TreeSet<Integer> set = new TreeSet<>(months);

        if (set.size() == 12) {
            return "Todo el año";
        }

        List<String> runs = new ArrayList<>();

        for (int start : set) {
            if (set.contains(previousMonth(start))) {
                continue;
            }

            int end = start;

            while (set.contains(nextMonth(end))) {
                end = nextMonth(end);
            }

            runs.add(end == start ? monthName(start) : monthName(start) + " - " + monthName(end));
        }

        return String.join(", ", runs);
    }

    private int nextMonth(int month) {
        return month == 12 ? 1 : month + 1;
    }

    private int previousMonth(int month) {
        return month == 1 ? 12 : month - 1;
    }

    private String monthName(int month) {
        String name = Month.of(month).getDisplayName(TextStyle.FULL, Locale.forLanguageTag("es"));
        return Character.toUpperCase(name.charAt(0)) + name.substring(1);
    }

    /**
     * Convierte un destino de la base de datos en su version para el cliente.
     *
     * @param requestedObject destino de la base de datos.
     * @return destino con el precio minimo ya convertido a pesos colombianos.
     */
    public LocationDTO objectToDto(Location requestedObject) {
        ClimateType climateType = requestedObject.getClimateType();
        Map<String, Double> tags = requestedObject.getTags() == null ? Map.of() : requestedObject.getTags();
        Map<String, Double> travelerFit = requestedObject.getTravelerFit() == null ? Map.of() : requestedObject.getTravelerFit();
        List<Integer> bestMonths = requestedObject.getBestMonths() == null ? List.of() : requestedObject.getBestMonths();

        return new LocationDTO(
                requestedObject.getLocationID(),
                requestedObject.getCityName(),
                requestedObject.getCountryName(),
                requestedObject.getIataCode(),
                requestedObject.getAirportName(),
                moneyExchange.convertUSDtoCOP(requestedObject.getCheapestPrice()),
                requestedObject.isFeatured(),
                requestedObject.getRating(),
                requestedObject.getRatingCount(),
                tags,
                travelerFit,
                bestMonths,
                monthsToText(bestMonths),
                climateType,
                climateType == null ? null : climateType.getLabel(),
                requestedObject.getCostLevel(),
                requestedObject.getVisaPolicy(),
                requestedObject.getEntryNote(),
                requestedObject.getImageUrl()
        );
    }
}