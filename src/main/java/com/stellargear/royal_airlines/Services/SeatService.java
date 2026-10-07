package com.stellargear.royal_airlines.Services;

import com.stellargear.royal_airlines.Models.DTOs.SeatDTO;
import com.stellargear.royal_airlines.Models.Entities.Seat;
import com.stellargear.royal_airlines.Repositories.SeatRepository;
import com.stellargear.royal_airlines.Utils.MoneyExchange;
import com.stellargear.royal_airlines.Utils.NotFoundException;
import lombok.RequiredArgsConstructor;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * Genera los asientos de un vuelo y controla su disponibilidad.
 */
@Service
@RequiredArgsConstructor
public class SeatService {

    private final SeatRepository seatRepository;
    private final MoneyExchange moneyExchange;
    private final MongoTemplate mongoTemplate;

    /**
     * Crea la parrilla completa de asientos de un vuelo.
     *
     * <p>Son seis filas de treinta asientos, guardados en una sola operacion. El precio baja
     * cuanto mas atras esta la fila: las cinco primeras filas son las mas caras.</p>
     *
     * @return identificadores de los asientos creados.
     */
    public List<String> generateSeats() {
        List<Seat> seats = new ArrayList<>();

        for (int row = 0; row < 6; row++) {

            char letter = (char) ('A' + row);

            for (int number = 1; number < 31; number++) {

                Seat newSeat = new Seat();
                newSeat.setReserved(false);
                newSeat.setSeatNumber(letter + "" + number);

                if (number < 6) {
                    newSeat.setSeatPrice(15.00);

                } else if (number < 13) {
                    newSeat.setSeatPrice(9.00);

                } else {
                    newSeat.setSeatPrice(5.00);
                }

                seats.add(newSeat);
            }
        }

        return seatRepository.saveAll(seats).stream().map(Seat::getSeatID).toList();
    }

    /**
     * Retiene varios asientos, todos o ninguno.
     *
     * <p>Si alguno ya esta ocupado, se liberan los que se hubieran reservado antes en esta misma
     * llamada y se responde 409.</p>
     *
     * @param seatIDs identificadores de los asientos a reservar.
     * @throws ResponseStatusException con codigo 409 si alguno ya no esta disponible.
     */
    public void reserveAll(List<String> seatIDs) {
        List<String> reserved = new ArrayList<>();

        for (String seatID : seatIDs) {
            if (!tryReserve(seatID)) {
                release(reserved);
                throw new ResponseStatusException(HttpStatus.CONFLICT,
                        "El asiento " + seatID + " ya no esta disponible");
            }

            reserved.add(seatID);
        }
    }

    /**
     * Intenta reservar un asiento, siempre que este libre.
     *
     * <p>La condicion de disponibilidad viaja en la propia consulta, de modo que dos reservas
     * simultaneas del mismo asiento no puedan reservar dos veces.</p>
     *
     * @param seatID identificador del asiento.
     * @return {@code true} si el asiento quedo reservado, {@code false} si ya estaba ocupado.
     */
    private boolean tryReserve(String seatID) {
        Query onlyIfFree = Query.query(Criteria.where("seatID").is(seatID).and("reserved").is(false));

        return mongoTemplate
                .updateFirst(onlyIfFree, Update.update("reserved", true), Seat.class)
                .getModifiedCount() == 1;
    }

    /**
     * Libera los asientos indicados para que vuelvan al catalogo.
     *
     * @param seatIDs identificadores de los asientos a liberar; se ignora si es {@code null} o vacio.
     */
    public void release(Collection<String> seatIDs) {
        if (seatIDs == null || seatIDs.isEmpty()) {
            return;
        }

        mongoTemplate.updateMulti(
                Query.query(Criteria.where("seatID").in(seatIDs)),
                Update.update("reserved", false),
                Seat.class);
    }

    /**
     * Busca varios asientos y los convierte a DTO.
     *
     * @param requestedList identificadores de los asientos.
     * @return asientos listos para serializar.
     * @throws NotFoundException si alguno de los asientos no existe.
     */
    public List<SeatDTO> searchAndConvertList(List<String> requestedList) {
        return objectListToDto(searchForListOfIDs(requestedList));
    }

    /**
     * Busca un asiento por su identificador.
     *
     * @param requestedID identificador del asiento.
     * @return asiento encontrado.
     * @throws NotFoundException si el asiento no existe.
     */
    public Seat searchByID(String requestedID) {
        return seatRepository.findById(requestedID)
                .orElseThrow(() -> new NotFoundException("Asiento no encontrado: " + requestedID));
    }

    /**
     * Busca varios asientos por su identificador en una sola consulta.
     *
     * <p>Devuelve los asientos en el mismo orden en que se pidio, para que la respuesta coincida
     * con la seleccion del usuario.</p>
     *
     * @param requestedIDs identificadores de los asientos a buscar.
     * @return asientos encontrados, en el orden solicitado.
     * @throws NotFoundException si alguno de los asientos no existe.
     */
    public List<Seat> searchForListOfIDs(List<String> requestedIDs) {
        Map<String, Seat> seatsByID = seatRepository.findAllById(requestedIDs).stream()
                .collect(Collectors.toMap(Seat::getSeatID, Function.identity()));

        return requestedIDs.stream()
                .map(id -> {
                    Seat seat = seatsByID.get(id);

                    if (seat == null) {
                        throw new NotFoundException("Asiento no encontrado: " + id);
                    }

                    return seat;
                })
                .toList();
    }

    /**
     * Convierte un asiento de la base de datos en su version para el cliente.
     *
     * @param requestedObject asiento de la base de datos.
     * @return asiento con el precio ya convertido a pesos colombianos.
     */
    public SeatDTO objectToDto(Seat requestedObject) {
        return new SeatDTO(
                requestedObject.getSeatID(),
                requestedObject.getSeatNumber(),
                moneyExchange.convertUSDtoCOP(requestedObject.getSeatPrice()),
                requestedObject.isReserved()
        );
    }

    /**
     * Convierte una lista de asientos de la base de datos en DTO.
     *
     * @param requestedList asientos a convertir.
     * @return lista de asientos convertidos.
     */
    public List<SeatDTO> objectListToDto(List<Seat> requestedList) {
        List<SeatDTO> returnedList = new ArrayList<>();

        for (Seat seat : requestedList) {
            returnedList.add(objectToDto(seat));
        }

        return returnedList;
    }
}