package com.stellargear.royal_airlines.Services;

import com.stellargear.royal_airlines.Models.DTOs.BoardingPassDTO;
import com.stellargear.royal_airlines.Models.Entities.BoardingPass;
import com.stellargear.royal_airlines.Models.Entities.Fee;
import com.stellargear.royal_airlines.Models.Entities.Flight;
import com.stellargear.royal_airlines.Models.Entities.Seat;
import com.stellargear.royal_airlines.Models.Enums.BoardingPassStatus;
import com.stellargear.royal_airlines.Repositories.BoardingPassRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;
import java.util.Random;

/**
 * Emite los pases de abordar y los consulta por usuario.
 *
 * <p>El pase se genera al confirmar una reserva e incluye una copia de los datos del vuelo para
 * poder mostrarse sin volver a consultar la reserva original.</p>
 */
@Service
@RequiredArgsConstructor
public class BoardingPassService {

    /** Letras de puerta disponibles al asignar un pase. */
    private static final char[] GATE_NUMBERS = {'A', 'B', 'C', 'D'};

    private final BoardingPassRepository boardingPassRepository;
    private final LocationService locationService;

    /**
     * Crea y guarda el pase de abordar de una reserva confirmada.
     *
     * @param userID propietario de la reserva.
     * @param seats asientos comprados.
     * @param flight vuelo reservado.
     * @param fee tarifa comprada, que determina la clase del pase.
     */
    public void createBoardingPass(String userID, List<Seat> seats, Flight flight, Fee fee) {
        BoardingPass newPass = new BoardingPass();

        Random numberPicker = new Random();
        List<String> seatIDs = new ArrayList<>();
        List<String> seatNumbers = new ArrayList<>();

        for (Seat seat : seats) {
            seatIDs.add(seat.getSeatID());
            seatNumbers.add(seat.getSeatNumber());
        }

        newPass.setBookedUserID(userID);
        newPass.setStatus(BoardingPassStatus.ACTIVE);
        newPass.setGroup(String.valueOf(numberPicker.nextInt(1, 20)));
        newPass.setGate(generateGate());

        newPass.setSeats(seatNumbers);
        newPass.setBookedSeatIDs(seatIDs);
        newPass.setSeatClass(fee.getFeeName());

        newPass.setAirline(flight.getAirline());
        newPass.setDepartureDate(flight.getDepartureDate());
        newPass.setFlightNumber(flight.getFlightNumber());
        newPass.setBookedFlightID(flight.getFlightID());
        newPass.setArrivalIataCode(locationService.searchByID(flight.getArrivalLocationID()).getIataCode());
        newPass.setDepartureIataCode(locationService.searchByID(flight.getDepartureLocationID()).getIataCode());

        boardingPassRepository.save(newPass);
    }

    /**
     * Elige una puerta de embarque al azar entre las disponibles.
     *
     * @return puerta con letra entre A y D y numero entre 1 y 3.
     */
    public String generateGate() {
        Random rng = new Random();

        int numberToSelect = rng.nextInt(GATE_NUMBERS.length);
        char letter = GATE_NUMBERS[numberToSelect];

        return letter + "" + rng.nextInt(1, 4);
    }

    /**
     * Lista todos los pases de un usuario.
     *
     * @param userID propietario de los pases.
     * @return pases del usuario, lista vacia si no tiene ninguno.
     */
    public List<BoardingPassDTO> getAllBoardingPassesOfUser(String userID) {
        return searchAndConvertListForUser(userID);
    }

    /**
     * Lista los pases vigentes de un usuario.
     *
     * @param userID propietario de los pases.
     * @return pases con estado activo.
     */
    public List<BoardingPassDTO> getAllActiveBoardingPassesOfUser(String userID) {
        return searchAndConvertActiveListForUser(userID);
    }

    /**
     * Lista los pases ya inutilizados de un usuario.
     *
     * @param userID propietario de los pases.
     * @return pases con estado inactivo.
     */
    public List<BoardingPassDTO> getAllInactiveBoardingPassesOfUser(String userID) {
        return searchAndConvertInactiveListForUser(userID);
    }

    /**
     * Convierte un pase de la base de datos en su version para el cliente.
     *
     * @param requestedObject pase de la base de datos.
     * @return pase listo para serializar.
     */
    public BoardingPassDTO objectToDto(BoardingPass requestedObject) {
        return new BoardingPassDTO(
                requestedObject.getBoardingPassID(),
                requestedObject.getPassengerInfo(),
                requestedObject.getSeats(),
                requestedObject.getSeatClass(),
                requestedObject.getGate(),
                requestedObject.getGroup(),
                requestedObject.getFlightNumber(),
                requestedObject.getAirline(),
                requestedObject.getDepartureIataCode(),
                requestedObject.getArrivalIataCode(),
                requestedObject.getDepartureDate()
        );
    }

    /**
     * Busca todos los pases de un usuario y los convierte.
     *
     * @param userToSearch propietario de los pases.
     * @return pases convertidos a DTO.
     */
    public List<BoardingPassDTO> searchAndConvertListForUser(String userToSearch) {
        return objectListToDto(boardingPassRepository.searchListByUserID(userToSearch));
    }

    /**
     * Busca los pases activos de un usuario y los convierte.
     *
     * @param userToSearch propietario de los pases.
     * @return pases activos convertidos a DTO.
     */
    public List<BoardingPassDTO> searchAndConvertActiveListForUser(String userToSearch) {
        return objectListToDto(boardingPassRepository.searchListByUserAndStatus(userToSearch, BoardingPassStatus.ACTIVE.name()));
    }

    /**
     * Busca los pases inactivos de un usuario y los convierte.
     *
     * @param userToSearch propietario de los pases.
     * @return pases inactivos convertidos a DTO.
     */
    public List<BoardingPassDTO> searchAndConvertInactiveListForUser(String userToSearch) {
        return objectListToDto(boardingPassRepository.searchListByUserAndStatus(userToSearch, BoardingPassStatus.INACTIVE.name()));
    }

    /**
     * Convierte una lista de pases de la base de datos en DTO.
     *
     * @param requestedList pases a convertir.
     * @return lista de pases convertidos.
     */
    public List<BoardingPassDTO> objectListToDto(List<BoardingPass> requestedList) {
        List<BoardingPassDTO> returnedList = new ArrayList<>();

        for (BoardingPass boardingPass : requestedList) {
            returnedList.add(objectToDto(boardingPass));
        }

        return returnedList;
    }
}