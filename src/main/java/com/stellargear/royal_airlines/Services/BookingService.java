package com.stellargear.royal_airlines.Services;

import com.stellargear.royal_airlines.Models.DTOs.BookingDTO;
import com.stellargear.royal_airlines.Models.DTOs.CreateBookingRequest;
import com.stellargear.royal_airlines.Models.Entities.Booking;
import com.stellargear.royal_airlines.Models.Entities.Fares;
import com.stellargear.royal_airlines.Models.Entities.Flight;
import com.stellargear.royal_airlines.Models.Enums.BookingStatus;
import com.stellargear.royal_airlines.Models.Enums.CancelReason;
import com.stellargear.royal_airlines.Repositories.BookingRepository;
import com.stellargear.royal_airlines.Utils.BadRequestException;
import com.stellargear.royal_airlines.Utils.ConflictException;
import com.stellargear.royal_airlines.Utils.MoneyExchange;
import com.stellargear.royal_airlines.Utils.NotFoundException;
import com.stellargear.royal_airlines.Utils.SeatCatalog;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;
import com.stellargear.royal_airlines.Models.Entities.Location;

import java.time.temporal.ChronoUnit;
import java.util.Comparator;
import java.util.LinkedHashSet;
import java.util.Locale;
import java.util.Objects;
import java.util.Set;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.List;

/**
 * Gestiona el ciclo de vida de las reservas.
 *
 * <p>Una reserva nace pendiente con sus asientos retenidos, se confirma o se cancela liberando
 * los asientos. Si nunca se confirma, la tarea programada la cancela pasado un tiempo para que
 * los asientos vuelvan al catalogo.</p>
 */
@Service
@RequiredArgsConstructor
public class BookingService {

    /** Minutos que una reserva queda retenida antes de expirar. */
    private static final long HOLD_MINUTES = 15;

    private static final Logger logger = LoggerFactory.getLogger(BookingService.class);

    private final BookingRepository bookingRepository;
    private final FlightService flightService;
    private final FaresService faresService;
    private final MoneyExchange moneyExchange;
    private final MongoTemplate mongoTemplate;
    private final SeatService seatService;
    private final LocationService locationService;

    /**
     * Crea una reserva pendiente y retiene sus asientos.
     *
     * <p>Valida la tarifa y las edades, retiene los asientos y guarda la reserva con los datos de
     * origen y destino copiados del vuelo. Si el guardado falla, libera los asientos retenidos.</p>
     *
     * @param bookingInfo datos de la reserva.
     * @param userID propietario de la reserva.
     * @return identificador de la reserva creada.
     * @throws BadRequestException si la tarifa o las edades no son validas.
     */
    public String bookFlight(CreateBookingRequest bookingInfo, String userID) {
        List<SeatCatalog.SeatInfo> seatInfo = seatService.parseAll(bookingInfo.seats());
        List<String> seatCodes = seatInfo.stream().map(SeatCatalog.SeatInfo::code).toList();

        List<Integer> passengerAges = bookingInfo.passengerAges();

        if (passengerAges != null && !passengerAges.isEmpty() && passengerAges.size() != seatCodes.size()) {
            throw new BadRequestException("Debes enviar una edad por cada asiento");
        }

        Flight flightInfo = flightService.searchFlightByID(bookingInfo.flightID());

        if (!flightInfo.getAvailableFareIDs().contains(bookingInfo.feeID())) {
            throw new BadRequestException("La tarifa no esta disponible para este vuelo");
        }

        Fares chosenFare = faresService.searchByID(bookingInfo.feeID());
        Location departure = locationService.searchByID(flightInfo.getDepartureLocationID());
        Location arrival = locationService.searchByID(flightInfo.getArrivalLocationID());

        double totalPrice = calculateTotalPrice(flightInfo.getFlightID(), seatCodes, bookingInfo.feeID());

        seatService.reserve(flightInfo.getFlightID(), seatCodes);

        LocalDateTime now = LocalDateTime.now();
        Booking.TripType tripType = bookingInfo.tripType() != null ? bookingInfo.tripType() : Booking.TripType.ONE_WAY;
        Booking.BookingSource source = bookingInfo.source() != null ? bookingInfo.source() : Booking.BookingSource.UNKNOWN;
        long leadDays = ChronoUnit.DAYS.between(now.toLocalDate(), flightInfo.getDepartureDate().toLocalDate());

        Booking newBooking = new Booking();
        newBooking.setBookedFlightID(bookingInfo.flightID());
        newBooking.setUserID(userID);
        newBooking.setBookedSeats(seatCodes);
        newBooking.setTicketCount(seatCodes.size());
        newBooking.setSelectedFee(bookingInfo.feeID());
        newBooking.setBookingDate(now);
        newBooking.setTotalPrice(totalPrice);
        newBooking.setStatus(BookingStatus.PENDING);

        newBooking.setDepartureLocationID(flightInfo.getDepartureLocationID());
        newBooking.setArrivalLocationID(flightInfo.getArrivalLocationID());
        newBooking.setDepartureCity(departure.getCityName());
        newBooking.setDepartureCountry(departure.getCountryName());
        newBooking.setArrivalCity(arrival.getCityName());
        newBooking.setArrivalCountry(arrival.getCountryName());

        newBooking.setLeadTimeDays((int) Math.max(0, leadDays));
        newBooking.setTripType(tripType);
        newBooking.setStayDays(tripType == Booking.TripType.ROUND_TRIP ? bookingInfo.stayDays() : null);
        newBooking.setCompanionType(bookingInfo.companionType());
        newBooking.setPassengerAges(passengerAges == null || passengerAges.isEmpty() ? null : List.copyOf(passengerAges));
        newBooking.setFareTier(chosenFare.getTierName());
        Set<String> extras = new LinkedHashSet<>();
        if (bookingInfo.extras() != null) {
            bookingInfo.extras().forEach(extra -> extras.add(extra.trim().toUpperCase(Locale.ROOT)));
        }
        extras.addAll(SeatCatalog.extrasFor(seatInfo));
        newBooking.setExtras(List.copyOf(extras));
        newBooking.setPricePaidVsCheapestPct(pricePremiumOverCheapest(flightInfo));
        newBooking.setSource(source);
        newBooking.setRecommendationID(source == Booking.BookingSource.RECOMMENDATION ? bookingInfo.recommendationID() : null);
        newBooking.setSchemaVersion(Booking.CURRENT_SCHEMA_VERSION);
        newBooking.setUpdatedAt(now);

        try {
            bookingRepository.save(newBooking);
        } catch (RuntimeException e) {
            seatService.release(flightInfo.getFlightID(), seatCodes);
            throw e;
        }

        logger.info("Reserva creada, id: {} por {} asientos", newBooking.getBookingID(), seatCodes.size());
        return newBooking.getBookingID();
    }

    /**
     * Compara el pasaje reservado con el mas barato disponible ahora en la misma ruta.
     *
     * @param bookedFlight vuelo reservado.
     * @return porcentaje por encima del mas barato (0 si es el mas barato), o {@code null} si no
     *         hay con que comparar.
     */
    private Double pricePremiumOverCheapest(Flight bookedFlight) {
        double cheapest = flightService.searchFlightsForLocation(bookedFlight.getArrivalLocationID()).stream()
                .filter(f -> Objects.equals(bookedFlight.getDepartureLocationID(), f.getDepartureLocationID()))
                .mapToDouble(Flight::getTicketPrice)
                .min()
                .orElse(0);

        if (cheapest <= 0) {
            return null;
        }

        double pct = (bookedFlight.getTicketPrice() - cheapest) / cheapest * 100;
        return BigDecimal.valueOf(pct).setScale(2, RoundingMode.HALF_UP).doubleValue();
    }

    /**
     * Confirma una reserva pendiente.
     *
     * @param requestingBookingID identificador de la reserva.
     * @param userID propietario de la reserva.
     */
    public void confirmBooking(String requestingBookingID, String userID) {
        transition(requestingBookingID, userID, List.of(BookingStatus.PENDING), BookingStatus.CONFIRMED, null);

        logger.info("Reserva confirmada, id: {}", requestingBookingID);
    }

    /**
     * Cancela una reserva pendiente o confirmada y libera sus asientos.
     *
     * @param requestingBookingID identificador de la reserva.
     * @param userID propietario de la reserva.
     */
    public void cancelBooking(String requestingBookingID, String userID) {
        Booking canceled = transition(requestingBookingID, userID, List.of(BookingStatus.PENDING, BookingStatus.CONFIRMED), BookingStatus.CANCELED, CancelReason.USER);

        seatService.release(canceled.getBookedFlightID(), canceled.getBookedSeats());

        logger.info("Reserva cancelada, id: {}", requestingBookingID);
    }

    /**
     * Registra la calificacion del viaje de una reserva confirmada.
     *
     * <p>Solo se acepta una vez y despues de que el vuelo haya llegado: el rating mide la
     * experiencia completa, no la compra. La escritura es atomica y solo actua sobre reservas
     * confirmadas sin calificar, asi que dos peticiones simultaneas no prevalecen.</p>
     *
     * @param requestingBookingID identificador de la reserva.
     * @param userID propietario de la reserva.
     * @param rating calificacion de 1 a 5.
     * @throws NotFoundException si la reserva no existe o es de otro usuario.
     * @throws ConflictException si la reserva no admite calificar en su estado actual.
     */
    public void rateBooking(String requestingBookingID, String userID, int rating) {
        Booking booking = searchByID(requestingBookingID);

        if (booking == null || !userID.equals(booking.getUserID())) {
            throw new NotFoundException("Reserva no encontrada");
        }

        Flight flight = flightService.searchFlightByID(booking.getBookedFlightID());
        LocalDateTime now = LocalDateTime.now();

        if (flight.getArrivalDate() == null || flight.getArrivalDate().isAfter(now)) {
            throw new ConflictException("Solo se puede calificar un viaje cuando el vuelo ya llego");
        }

        Booking rated = mongoTemplate.findAndModify(
                Query.query(Criteria.where("bookingID").is(requestingBookingID)
                        .and("userID").is(userID)
                        .and("status").is(BookingStatus.CONFIRMED)
                        .and("tripRating").exists(false)),
                Update.update("tripRating", rating).set("ratedAt", now),
                Booking.class);

        if (rated == null) {
            throw new ConflictException("La reserva no admite calificar en su estado actual");
        }

        logger.info("Reserva calificada, id: {} rating {}", requestingBookingID, rating);
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
                Booking expired = transition(pending.getBookingID(), null, List.of(BookingStatus.PENDING), BookingStatus.CANCELED, CancelReason.EXPIRED);
                seatService.release(expired.getBookedFlightID(), expired.getBookedSeats());
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
     * Cambia el estado de una reserva de forma atomica y escribe sus marcas de tiempo.
     *
     * <p>El filtro de estado y de propietario viaja dentro de la misma operacion, de modo que dos
     * peticiones simultaneas no puedan aplicar la misma transicion dos veces. Si el propietario
     * indicado no es {@code null}, la reserva debe pertenecer a ese usuario.</p>
     *
     * <p>Confirmar marca {@code confirmedAt}; cancelar marca {@code canceledAt} y el motivo.</p>
     *
     * @param bookingID identificador de la reserva.
     * @param userID propietario esperado, o {@code null} en las tareas internas.
     * @param allowedFrom estados desde los que se admite la transicion.
     * @param to estado de destino.
     * @param cancelReason motivo de la cancelacion, o {@code null} si no es una cancelacion.
     * @return la reserva tal como estaba antes de aplicar el cambio.
     * @throws NotFoundException si la reserva no existe o pertenece a otro usuario.
     * @throws ConflictException si la reserva no puede pasar al estado solicitado.
     */
    private Booking transition(String bookingID, String userID, List<BookingStatus> allowedFrom, BookingStatus to, CancelReason cancelReason) {
        Criteria criteria = Criteria.where("bookingID").is(bookingID).and("status").in(allowedFrom);

        if (userID != null) {
            criteria = criteria.and("userID").is(userID);
        }

        Update change = Update.update("status", to);

        if (to == BookingStatus.CONFIRMED) {
            change = change.set("confirmedAt", LocalDateTime.now());
        }

        if (to == BookingStatus.CANCELED) {
            change = change.set("canceledAt", LocalDateTime.now()).set("cancelReason", cancelReason);
        }

        Booking previous = mongoTemplate.findAndModify(Query.query(criteria), change, Booking.class);

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
        Fares requestedFares = faresService.searchByID(fee);
        int ticketQuantity = seats.size();
        double totalSeatPrice = seatService.totalPriceUsd(seatService.parseAll(seats));

        double totalPrice = ((requestedFlight.getTicketPrice() * requestedFares.getPriceDifference()) * ticketQuantity) + totalSeatPrice;
        BigDecimal bigDecimalTotal = new BigDecimal(totalPrice).setScale(2, RoundingMode.HALF_UP);

        return bigDecimalTotal.doubleValue();
    }

    /**
     * Lista todas las reservas de un usuario, de la mas reciente a la mas antigua.
     *
     * @param userID propietario de las reservas.
     * @return reservas convertidas a DTO, lista vacia si no tiene ninguna.
     */
    public List<BookingDTO> searchAllByUser(String userID) {
        List<BookingDTO> bookings = bookingRepository.searchListByUserID(userID).stream()
                .sorted(Comparator.comparing(Booking::getBookingDate, Comparator.nullsLast(Comparator.reverseOrder())))
                .map(this::objectToDto)
                .toList();

        logger.info("Reservas listadas para usuario {}: {}", userID, bookings.size());
        return bookings;
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
                faresService.searchAndConvert(requestedObject.getSelectedFee()),
                moneyExchange.convertUSDtoCOP(requestedObject.getTotalPrice()),
                requestedObject.getStatus(),
                requestedObject.getTicketCount(),
                requestedObject.getBookedSeats(),
                requestedObject.getBookedFlightID(),
                requestedObject.getSelectedFee(),
                requestedObject.getCompanionType(),
                requestedObject.getCancelReason(),
                requestedObject.getTripRating()
        );
    }
}