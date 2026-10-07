package com.stellargear.royal_airlines.Services;

import com.stellargear.royal_airlines.Models.DTOs.BookingDTO;
import com.stellargear.royal_airlines.Models.DTOs.CreateBookingRequest;
import com.stellargear.royal_airlines.Models.Entities.Booking;
import com.stellargear.royal_airlines.Models.Entities.Fee;
import com.stellargear.royal_airlines.Models.Entities.Flight;
import com.stellargear.royal_airlines.Models.Entities.Seat;
import com.stellargear.royal_airlines.Models.Enums.BookingStatus;
import com.stellargear.royal_airlines.Repositories.BookingRepository;
import com.stellargear.royal_airlines.Utils.ConflictException;
import com.stellargear.royal_airlines.Utils.MoneyExchange;
import com.stellargear.royal_airlines.Utils.NotFoundException;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.http.HttpStatus;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.HashSet;
import java.util.List;

/**
 * Gestiona el ciclo de vida de las reservas.
 *
 * <p>Una reserva nace pendiente con sus asientos retenidos, se confirma emitiendo el pase de
 * abordar o se cancela liberando los asientos. Si nunca se confirma, la tarea programada la
 * cancela pasado un tiempo para que los asientos vuelvan al catalogo.</p>
 */
@Service
@RequiredArgsConstructor
public class BookingService {

    /** Minutos que una reserva queda retenida antes de expirar. */
    private static final long HOLD_MINUTES = 15;

    private static final Logger logger = LoggerFactory.getLogger(BookingService.class);

    private final BookingRepository bookingRepository;
    private final SeatService seatService;
    private final FlightService flightService;
    private final FeeService feeService;
    private final MoneyExchange moneyExchange;
    private final BoardingPassService boardingPassService;
    private final MongoTemplate mongoTemplate;

    /**
     * Crea una reserva pendiente y retiene los asientos elegidos.
     *
     * <p>El propietario sale siempre del token. Si el vuelo no existe se responde 404, y si los
     * asientos ya no estan disponibles la operacion responde 409.</p>
     *
     * @param bookingInfo vuelo, tarifa y asientos solicitados.
     * @param userID propietario de la reserva, tomado del token.
     * @return identificador de la reserva creada.
     */
    public String bookFlight(CreateBookingRequest bookingInfo, String userID) {
        List<String> seatIDs = bookingInfo.seatIDs().stream().distinct().toList();

        if (seatIDs.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Debes elegir al menos un asiento");
        }

        Flight flightInfo = flightService.searchFlightByID(bookingInfo.flightID());

        if (!new HashSet<>(flightInfo.getAvailableSeatIDs()).containsAll(seatIDs)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Hay asientos que no pertenecen al vuelo");
        }

        if (!flightInfo.getAvailableFeeIDs().contains(bookingInfo.feeID())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "La tarifa no esta disponible para este vuelo");
        }

        double totalPrice = calculateTotalPrice(flightInfo.getFlightID(), seatIDs, bookingInfo.feeID());

        seatService.reserveAll(seatIDs);

        Booking newBooking = new Booking();
        newBooking.setBookedFlightID(bookingInfo.flightID());
        newBooking.setUserID(userID);
        newBooking.setBookedSeatIDs(seatIDs);
        newBooking.setTicketCount(seatIDs.size());
        newBooking.setSelectedFee(bookingInfo.feeID());
        newBooking.setBookingDate(LocalDateTime.now());
        newBooking.setTotalPrice(totalPrice);
        newBooking.setStatus(BookingStatus.PENDING);

        try {
            bookingRepository.save(newBooking);
        } catch (RuntimeException e) {
            seatService.release(seatIDs);
            throw e;
        }

        logger.info("Reserva creada, id: {} por {} asientos", newBooking.getBookingID(), seatIDs.size());
        return newBooking.getBookingID();
    }

    /**
     * Confirma una reserva pendiente y emite su pase de abordar.
     *
     * <p>Si el pase no puede emitirse, la reserva vuelve a quedar pendiente.</p>
     *
     * @param requestingBookingID identificador de la reserva.
     * @param userID propietario de la reserva.
     */
    public void confirmBooking(String requestingBookingID, String userID) {
        Booking bookingToConfirm = transition(requestingBookingID, userID, List.of(BookingStatus.PENDING), BookingStatus.CONFIRMED);

        try {
            searchAndSendDataToBoarding(bookingToConfirm);
        } catch (RuntimeException e) {
            setStatus(requestingBookingID, BookingStatus.PENDING);
            throw e;
        }

        logger.info("Reserva confirmada, id: {}", requestingBookingID);
    }

    /**
     * Reune los datos de la reserva y emite el pase de abordar.
     *
     * @param dataToSend reserva confirmada.
     */
    public void searchAndSendDataToBoarding(Booking dataToSend) {
        List<Seat> seats = seatService.searchForListOfIDs(dataToSend.getBookedSeatIDs());
        Flight flight = flightService.searchFlightByID(dataToSend.getBookedFlightID());
        Fee fee = feeService.searchByID(dataToSend.getSelectedFee());

        boardingPassService.createBoardingPass(dataToSend.getUserID(), seats, flight, fee);
    }

    /**
     * Cancela una reserva pendiente o confirmada y libera sus asientos.
     *
     * @param requestingBookingID identificador de la reserva.
     * @param userID propietario de la reserva.
     */
    public void cancelBooking(String requestingBookingID, String userID) {
        Booking canceled = transition(requestingBookingID, userID, List.of(BookingStatus.PENDING, BookingStatus.CONFIRMED), BookingStatus.CANCELED);

        seatService.release(canceled.getBookedSeatIDs());

        logger.info("Reserva cancelada, id: {}", requestingBookingID);
    }

    /**
     * Cancela las reservas pendientes que superaron el tiempo de retencion.
     *
     * <p>Se ejecuta cada minuto. Las reservas que ya no admiten la transicion se ignoran en
     * silencio, porque significa que otro proceso las movio primero.</p>
     */
    @Scheduled(fixedDelay = 60_000)
    public void expirePendingBookings() {
        LocalDateTime limit = LocalDateTime.now().minusMinutes(HOLD_MINUTES);
        int expiredCount = 0;

        for (Booking pending : bookingRepository.findByStatusAndBookingDateBefore(BookingStatus.PENDING, limit)) {
            try {
                Booking expired = transition(pending.getBookingID(), null, List.of(BookingStatus.PENDING), BookingStatus.CANCELED);
                seatService.release(expired.getBookedSeatIDs());
                expiredCount++;
            } catch (ResponseStatusException alreadyHandled) {
                continue;
            }
        }

        if (expiredCount > 0) {
            logger.info("Reservas pendientes expiradas: {}", expiredCount);
        }
    }

    /**
     * Cambia el estado de una reserva de forma atomica.
     *
     * <p>El filtro de estado y de propietario viaja dentro de la misma operacion, de modo que dos
     * peticiones simultaneas no puedan aplicar la misma transicion dos veces. Si el propietario
     * indicado no es {@code null}, la reserva debe pertenecer a ese usuario.</p>
     *
     * @param bookingID identificador de la reserva.
     * @param userID propietario esperado, o {@code null} en las tareas internas.
     * @param allowedFrom estados desde los que se admite la transicion.
     * @param to estado de destino.
     * @return la reserva tal como estaba antes de aplicar el cambio.
     * @throws NotFoundException si la reserva no existe o pertenece a otro usuario.
     * @throws ConflictException si la reserva no puede pasar al estado solicitado.
     */
    private Booking transition(String bookingID, String userID, List<BookingStatus> allowedFrom, BookingStatus to) {
        Criteria criteria = Criteria.where("bookingID").is(bookingID).and("status").in(allowedFrom);

        if (userID != null) {
            criteria = criteria.and("userID").is(userID);
        }

        Booking previous = mongoTemplate.findAndModify(Query.query(criteria), Update.update("status", to), Booking.class);

        if (previous == null) {
            Booking existing = bookingRepository.searchByID(bookingID);

            if (existing == null || (userID != null && !userID.equals(existing.getUserID()))) {
                throw new NotFoundException("Reserva no encontrada");
            }

            throw new ConflictException("La reserva no puede pasar a " + to + " desde su estado actual");
        }

        return previous;
    }

    /**
     * Fuerza un estado concreto sin comprobar las transiciones permitidas.
     *
     * @param bookingID identificador de la reserva.
     * @param status estado a aplicar.
     */
    private void setStatus(String bookingID, BookingStatus status) {
        mongoTemplate.updateFirst(
                Query.query(Criteria.where("bookingID").is(bookingID)),
                Update.update("status", status),
                Booking.class);
    }

    /**
     * Calcula el importe total de una reserva en dolares.
     *
     * <p>El total es el precio del pasaje ajustado por la tarifa, multiplicado por el numero de
     * pasajeros, mas el precio de cada asiento.</p>
     *
     * @param flight identificador del vuelo.
     * @param seats identificadores de los asientos.
     * @param fee identificador de la tarifa.
     * @return total redondeado a dos decimales.
     */
    public double calculateTotalPrice(String flight, List<String> seats, String fee) {
        Flight requestedFlight = flightService.searchFlightByID(flight);
        List<Seat> requestedSeats = seatService.searchForListOfIDs(seats);
        Fee requestedFee = feeService.searchByID(fee);
        int ticketQuantity = seats.size();
        double totalSeatPrice = 0;

        for (Seat requestedSeat : requestedSeats) {
            totalSeatPrice += requestedSeat.getSeatPrice();
        }

        double totalPrice = ((requestedFlight.getTicketPrice() * requestedFee.getPriceDifference()) * ticketQuantity) + totalSeatPrice;
        BigDecimal bigDecimalTotal = new BigDecimal(totalPrice).setScale(2, RoundingMode.HALF_UP);

        return bigDecimalTotal.doubleValue();
    }

    /**
     * Devuelve una reserva comprobando que pertenezca al usuario indicado.
     *
     * @param requestedID identificador de la reserva.
     * @param userID propietario esperado.
     * @return reserva convertida a DTO.
     * @throws NotFoundException si la reserva no existe o es de otro usuario.
     */
    public BookingDTO searchAndReturnObject(String requestedID, String userID) {
        Booking booking = searchByID(requestedID);

        if (booking == null || !userID.equals(booking.getUserID())) {
            throw new NotFoundException("Reserva no encontrada");
        }

        return objectToDto(booking);
    }

    /**
     * Busca una reserva por su identificador.
     *
     * @param requestedID identificador de la reserva.
     * @return reserva encontrada o {@code null}.
     */
    public Booking searchByID(String requestedID) {
        return bookingRepository.searchByID(requestedID);
    }

    /**
     * Convierte una reserva de la base de datos en su version para el cliente.
     *
     * @param requestedObject reserva de la base de datos.
     * @return reserva con vuelo, asientos y tarifa ya expandidos.
     */
    public BookingDTO objectToDto(Booking requestedObject) {
        return new BookingDTO(
                requestedObject.getBookingID(),
                requestedObject.getUserID(),
                flightService.searchAndConvertObject(requestedObject.getBookedFlightID()),
                seatService.searchAndConvertList(requestedObject.getBookedSeatIDs()),
                feeService.searchAndConvertObject(requestedObject.getSelectedFee()),
                moneyExchange.convertUSDtoCOP(requestedObject.getTotalPrice()),
                requestedObject.getStatus(),
                requestedObject.getTicketCount(),
                null,
                requestedObject.getBookedFlightID(),
                requestedObject.getSelectedFee()
        );
    }
}