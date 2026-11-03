package com.stellargear.royal_airlines.Services;

import com.stellargear.royal_airlines.Models.DTOs.FaresDTO;
import com.stellargear.royal_airlines.Models.Entities.Fares;
import com.stellargear.royal_airlines.Repositories.FaresRepository;
import com.stellargear.royal_airlines.Utils.MoneyExchange;
import com.stellargear.royal_airlines.Utils.NotFoundException;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * Consulta las tarifas de pasaje y las convierte a DTO.
 */
@Service
@RequiredArgsConstructor
public class FaresService {

    private final FaresRepository faresRepository;
    private final MoneyExchange moneyExchange;

    /**
     * Registra una tarifa nueva.
     *
     * @param request datos de la tarifa.
     * @return {@code 201 Created} si se guardo.
     */
    public ResponseEntity<?> createFare (FaresDTO request) {

        Fares newFare = new Fares();
        newFare.setPriceDifference(request.priceDifference());
        newFare.setTierName(request.tierName());
        newFare.setTravelClass(request.travelClass());
        newFare.setTierRank(request.tierRank());
        newFare.setCheckedBagKg(request.checkedBagKg());
        newFare.setCarryOnKg(request.carryOnKg());
        newFare.setBenefits(request.benefits());
        newFare.setSchemaVersion(Fares.CURRENT_SCHEMA_VERSION);
        newFare.setUpdatedAt(java.time.LocalDateTime.now());

        faresRepository.save(newFare);

        return new ResponseEntity<>(HttpStatus.CREATED);
    }

    /**
     * Devuelve los identificadores de todas las tarifas del catalogo.
     *
     * @return identificadores de las tarifas existentes.
     */
    public List<String> getFees() {
        List<Fares> repoFares = faresRepository.findAll();
        return getIDs(repoFares);
    }

    /**
     * Carga varias tarifas en una sola consulta.
     *
     * @param ids identificadores de las tarifas.
     * @return mapa de identificador a tarifa.
     */
    public Map<String, Fares> loadByIDs(Collection<String> ids) {
        return faresRepository.findAllById(ids).stream()
                .collect(Collectors.toMap(Fares::getFareID, f -> f));
    }

    /**
     * Convierte las tarifas indicadas usando un mapa ya cargado.
     *
     * @param ids identificadores de las tarifas.
     * @param byId tarifas indexadas por identificador.
     * @param price precio del pasaje en dolares.
     * @return tarifas convertidas, omitiendo los identificadores que no existan.
     */
    public List<FaresDTO> convertList(List<String> ids, Map<String, Fares> byId, double price) {
        List<Fares> list = new ArrayList<>();
        if (ids != null) {
            for (String id : ids) {
                Fares fare = byId.get(id);
                if (fare != null) list.add(fare);
            }
        }
        return objectListToDto(list, price);
    }

    /**
     * Busca una tarifa por su identificador.
     *
     * @param requestedID identificador de la tarifa.
     * @return tarifa encontrada.
     * @throws NotFoundException si la tarifa no existe.
     */
    public Fares searchByID(String requestedID) {
        Fares fare = faresRepository.findByFareID(requestedID);

        if (fare == null) {
            throw new NotFoundException("Tarifa no encontrada: " + requestedID);
        }

        return fare;
    }

    /**
     * Extrae los identificadores de una lista de tarifas.
     *
     * @param requestedList tarifas de las que se extraen los identificadores.
     * @return lista de identificadores.
     */
    public List<String> getIDs(List<Fares> requestedList) {
        List<String> returnedList = new ArrayList<>();

        for (Fares fares : requestedList) {
            returnedList.add(fares.getFareID());
        }

        return returnedList;
    }

    /**
     * Convierte varias tarifas calculando su precio sobre un pasaje base.
     *
     * @param requestedList identificadores de las tarifas.
     * @param price precio del pasaje en dolares.
     * @return tarifas con su importe ya convertido a pesos colombianos.
     */
    public List<FaresDTO> searchAndConvertList(List<String> requestedList, double price) {
        List<Fares> objectList = new ArrayList<>();

        for (String s : requestedList) {
            objectList.add(searchByID(s));
        }

        return objectListToDto(objectList, price);
    }

    /**
     * Busca una tarifa y la convierte a DTO sin precio calculado.
     *
     * @param requestedFare identificador de la tarifa.
     * @return tarifa convertida.
     * @throws NotFoundException si la tarifa no existe.
     */
    public FaresDTO searchAndConvert (String requestedFare) {
        Fares fare = searchByID(requestedFare);
        return objectToDto(fare, 0);
    }

    /**
     * Convierte una tarifa a DTO calculando su precio sobre un pasaje base.
     *
     * @param requestedObject tarifa de la base de datos.
     * @param ticketPrice precio del pasaje en dolares.
     * @return tarifa con su importe ya convertido a pesos colombianos.
     */
    private FaresDTO objectToDto(Fares requestedObject, double ticketPrice) {
        return new FaresDTO(
                requestedObject.getFareID(),
                requestedObject.getTravelClass(),
                requestedObject.getTierName(),
                requestedObject.getPriceDifference(),
                requestedObject.getTierRank(),
                requestedObject.getCheckedBagKg(),
                requestedObject.getCarryOnKg(),
                requestedObject.getBenefits() == null ? List.of() : requestedObject.getBenefits(),
                moneyExchange.calculateFees(requestedObject.getPriceDifference(), ticketPrice)
        );
    }

    /**
     * Convierte una lista de tarifas a DTO calculando sus precios.
     *
     * @param requestedList tarifas de la base de datos.
     * @param price precio del pasaje en dolares.
     * @return lista de tarifas convertidas.
     */
    private List<FaresDTO> objectListToDto(List<Fares> requestedList, double price) {
        return requestedList.stream().map(fares -> objectToDto(fares, price)).toList();
    }
}