package com.stellargear.royal_airlines.Services;

import com.stellargear.royal_airlines.Models.DTOs.SeatMapDTO;
import com.stellargear.royal_airlines.Models.Entities.Flight;
import com.stellargear.royal_airlines.Utils.BadRequestException;
import com.stellargear.royal_airlines.Utils.ConflictException;
import com.stellargear.royal_airlines.Utils.MoneyExchange;
import com.stellargear.royal_airlines.Utils.NotFoundException;
import com.stellargear.royal_airlines.Utils.SeatCatalog;
import com.stellargear.royal_airlines.Utils.SeatCatalog.SeatInfo;
import lombok.RequiredArgsConstructor;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.Collection;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

/**
 * Valida, retiene y libera asientos. Los ocupados viven en {@code Flight.takenSeats}.
 */
@Service
@RequiredArgsConstructor
public class SeatService {

    private final MongoTemplate mongoTemplate;
    private final MoneyExchange moneyExchange;
    private final FlightService flightService;

    /**
     * Valida los codigos recibidos y descarta repetidos.
     *
     * @param rawCodes codigos de asiento enviados por el cliente.
     * @return asientos validos, sin repetir y en el orden recibido.
     * @throws BadRequestException si algun codigo no existe en la cabina.
     */
    public List<SeatInfo> parseAll(List<String> rawCodes) {
        List<SeatInfo> seats = new ArrayList<>();
        Set<String> seen = new LinkedHashSet<>();

        for (String raw : rawCodes) {
            SeatInfo info = SeatCatalog.parse(raw).orElseThrow(() ->
                    new BadRequestException("Asiento invalido: " + raw));

            if (seen.add(info.code())) {
                seats.add(info);
            }
        }

        return seats;
    }

    /**
     * Suma el precio en dolares de los asientos indicados.
     *
     * @param seats asientos ya resueltos.
     * @return precio total en dolares.
     */
    public double totalPriceUsd(List<SeatInfo> seats) {
        return seats.stream().mapToDouble(SeatInfo::priceUsd).sum();
    }

    /**
     * Retiene varios asientos de un vuelo, todos o ninguno, en una sola operacion atomica.
     *
     * <p>El filtro exige que ninguno este ocupado, asi que dos reservas simultaneas no pueden
     * llevarse el mismo asiento.</p>
     *
     * @param flightID identificador del vuelo.
     * @param codes asientos a retener.
     * @throws NotFoundException si el vuelo no existe.
     * @throws ConflictException si algun asiento ya no esta disponible.
     */
    public void reserve(String flightID, List<String> codes) {
        Query onlyIfAllFree = Query.query(Criteria.where("flightID").is(flightID)
                .and("takenSeats").nin(codes));

        Update hold = new Update()
                .push("takenSeats").each(codes.toArray())
                .inc("seatsLeft", -codes.size());

        if (mongoTemplate.updateFirst(onlyIfAllFree, hold, Flight.class).getModifiedCount() == 1) {
            return;
        }

        if (!mongoTemplate.exists(Query.query(Criteria.where("flightID").is(flightID)), Flight.class)) {
            throw new NotFoundException("Vuelo no encontrado: " + flightID);
        }

        throw new ConflictException("Alguno de los asientos ya no esta disponible");
    }

    /**
     * Libera asientos de un vuelo.
     *
     * <p>Solo actua si todos siguen ocupados, de modo que liberar dos veces la misma reserva no
     * descuadra el contador.</p>
     *
     * @param flightID identificador del vuelo.
     * @param codes asientos a liberar.
     */
    public void release(String flightID, Collection<String> codes) {
        if (codes == null || codes.isEmpty()) {
            return;
        }

        Query onlyIfAllTaken = Query.query(Criteria.where("flightID").is(flightID)
                .and("takenSeats").all(codes));

        Update free = new Update()
                .pullAll("takenSeats", codes.toArray())
                .inc("seatsLeft", codes.size());

        mongoTemplate.updateFirst(onlyIfAllTaken, free, Flight.class);
    }

    /**
     * Arma el mapa de asientos de un vuelo para el cliente.
     *
     * @param flightID identificador del vuelo.
     * @return distribucion, precios y asientos ocupados.
     * @throws NotFoundException si el vuelo no existe.
     */
    public SeatMapDTO getSeatMap(String flightID) {
        Flight flight = flightService.searchFlightByID(flightID);
        List<String> taken = flight.getTakenSeats() == null ? List.of() : List.copyOf(flight.getTakenSeats());

        List<SeatMapDTO.CategoryDTO> categories = new ArrayList<>();
        for (SeatCatalog.Category category : SeatCatalog.Category.values()) {
            categories.add(new SeatMapDTO.CategoryDTO(
                    category.name(), category.fromRow(), category.toRow(),
                    moneyExchange.convertUSDtoCOP(category.priceUsd())));
        }

        return new SeatMapDTO(
                flightID,
                SeatCatalog.ROWS,
                SeatCatalog.COLUMNS,
                categories,
                SeatCatalog.EXTRA_LEGROOM_ROWS.stream().sorted().toList(),
                taken,
                SeatCatalog.CAPACITY - taken.size());
    }
}
