package com.stellargear.royal_airlines.Services;

import com.stellargear.royal_airlines.Models.DTOs.FeeDTO;
import com.stellargear.royal_airlines.Models.Entities.Fee;
import com.stellargear.royal_airlines.Repositories.FeeRepository;
import com.stellargear.royal_airlines.Utils.MoneyExchange;
import com.stellargear.royal_airlines.Utils.NotFoundException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;

/**
 * Consulta las tarifas de pasaje y las convierte a DTO.
 */
@Service
@RequiredArgsConstructor
public class FeeService {

    private final FeeRepository feeRepository;
    private final MoneyExchange moneyExchange;

    /**
     * Devuelve los identificadores de todas las tarifas del catalogo.
     *
     * @return identificadores de las tarifas existentes.
     */
    public List<String> getFees() {
        List<Fee> repoFees = feeRepository.findAll();
        return getIDs(repoFees);
    }

    /**
     * Extrae los identificadores de una lista de tarifas.
     *
     * @param requestedList tarifas de las que se extraen los identificadores.
     * @return lista de identificadores.
     */
    public List<String> getIDs(List<Fee> requestedList) {
        List<String> returnedList = new ArrayList<>();

        for (Fee fee : requestedList) {
            returnedList.add(fee.getFeeID());
        }

        return returnedList;
    }

    /**
     * Busca una tarifa y la convierte sin calcular su precio.
     *
     * @param requestedID identificador de la tarifa.
     * @return tarifa sin importe, adecuada cuando el precio ya no aporta.
     */
    public FeeDTO searchAndConvertObject(String requestedID) {
        return simpleObjectToDto(searchByID(requestedID));
    }

    /**
     * Convierte varias tarifas calculando su precio sobre un pasaje base.
     *
     * @param requestedList identificadores de las tarifas.
     * @param price precio del pasaje en dolares.
     * @return tarifas con su importe ya convertido a pesos colombianos.
     */
    public List<FeeDTO> searchAndConvertList(List<String> requestedList, double price) {
        List<Fee> objectList = new ArrayList<>();

        for (String s : requestedList) {
            objectList.add(searchByID(s));
        }

        return objectListToDto(objectList, price);
    }

    /**
     * Busca una tarifa por su identificador.
     *
     * @param requestedID identificador de la tarifa.
     * @return tarifa encontrada.
     * @throws NotFoundException si la tarifa no existe.
     */
    public Fee searchByID(String requestedID) {
        return feeRepository.findById(requestedID)
                .orElseThrow(() -> new NotFoundException("Tarifa no encontrada: " + requestedID));
    }

    /**
     * Convierte una tarifa a DTO dejando el importe en nulo.
     *
     * @param requestedObject tarifa de la base de datos.
     * @return tarifa sin importe.
     */
    public FeeDTO simpleObjectToDto(Fee requestedObject) {
        return new FeeDTO(requestedObject.getFeeID(), requestedObject.getFeeName(), requestedObject.getPriceDifference(), null);
    }

    /**
     * Convierte una tarifa a DTO calculando su precio sobre un pasaje base.
     *
     * @param requestedObject tarifa de la base de datos.
     * @param ticketPrice precio del pasaje en dolares.
     * @return tarifa con su importe ya convertido a pesos colombianos.
     */
    public FeeDTO objectToDto(Fee requestedObject, double ticketPrice) {
        return new FeeDTO(
                requestedObject.getFeeID(),
                requestedObject.getFeeName(),
                requestedObject.getPriceDifference(),
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
    public List<FeeDTO> objectListToDto(List<Fee> requestedList, double price) {
        List<FeeDTO> returnedList = new ArrayList<>();

        for (Fee fee : requestedList) {
            returnedList.add(objectToDto(fee, price));
        }

        return returnedList;
    }
}