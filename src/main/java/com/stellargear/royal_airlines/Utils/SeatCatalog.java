package com.stellargear.royal_airlines.Utils;

import java.util.Collection;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Optional;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Distribucion fija de la cabina y atributos de cada asiento, calculados a partir de su codigo.
 *
 * <p>No se guarda nada en base de datos: un codigo como {@code 12B} basta para saber su
 * categoria, precio, posicion y si tiene espacio extra.</p>
 */
public final class SeatCatalog {

    public static final int ROWS = 15;
    public static final List<String> COLUMNS = List.of("A", "B", "C", "D", "E", "F");
    public static final int CAPACITY = ROWS * COLUMNS.size();

    /** Filas con espacio extra para las piernas (cabecera y salida de emergencia). */
    public static final Set<Integer> EXTRA_LEGROOM_ROWS = Set.of(1, 8);

    private static final Pattern CODE = Pattern.compile("^(\\d{1,2})([A-F])$");

    public enum Category {
        PREFERENTE(1, 3, 15.00),
        PLUS(4, 7, 9.00),
        ESTANDAR(8, 15, 5.00);

        private final int fromRow;
        private final int toRow;
        private final double priceUsd;

        Category(int fromRow, int toRow, double priceUsd) {
            this.fromRow = fromRow;
            this.toRow = toRow;
            this.priceUsd = priceUsd;
        }

        public int fromRow() { return fromRow; }
        public int toRow() { return toRow; }
        public double priceUsd() { return priceUsd; }

        public static Category forRow(int row) {
            for (Category category : values()) {
                if (row >= category.fromRow && row <= category.toRow) {
                    return category;
                }
            }
            throw new IllegalArgumentException("Fila fuera de rango: " + row);
        }
    }

    public enum Position { WINDOW, MIDDLE, AISLE }

    /** Atributos de un asiento. El precio va en dolares, como el resto de precios del backend. */
    public record SeatInfo(
            String code,
            int row,
            String column,
            Category category,
            Position position,
            double priceUsd,
            boolean extraLegroom
    ) {}

    private SeatCatalog() {}

    /**
     * Interpreta un codigo de asiento.
     *
     * @param rawCode codigo como {@code 12B}; se ignoran espacios y mayusculas.
     * @return los atributos del asiento, o vacio si el codigo no existe en la cabina.
     */
    public static Optional<SeatInfo> parse(String rawCode) {
        if (rawCode == null) {
            return Optional.empty();
        }

        Matcher matcher = CODE.matcher(rawCode.trim().toUpperCase(Locale.ROOT));

        if (!matcher.matches()) {
            return Optional.empty();
        }

        int row = Integer.parseInt(matcher.group(1));

        if (row < 1 || row > ROWS) {
            return Optional.empty();
        }

        String column = matcher.group(2);
        Category category = Category.forRow(row);

        return Optional.of(new SeatInfo(
                row + column, row, column, category, positionOf(column),
                category.priceUsd(), EXTRA_LEGROOM_ROWS.contains(row)));
    }

    private static Position positionOf(String column) {
        return switch (column) {
            case "A", "F" -> Position.WINDOW;
            case "B", "E" -> Position.MIDDLE;
            default -> Position.AISLE;
        };
    }

    /**
     * Etiquetas de {@code Booking.extras} que se derivan de los asientos elegidos.
     *
     * <p>Alimentan al recomendador: disposicion a pagar por asiento y preferencia de
     * ventana o pasillo.</p>
     */
    public static Set<String> extrasFor(Collection<SeatInfo> seats) {
        Set<String> extras = new LinkedHashSet<>();

        for (SeatInfo seat : seats) {
            if (seat.category() != Category.ESTANDAR) {
                extras.add("SEAT_" + seat.category().name());
            }
            if (seat.extraLegroom()) {
                extras.add("SEAT_EXTRA_LEGROOM");
            }
            if (seat.position() != Position.MIDDLE) {
                extras.add("SEAT_" + seat.position().name());
            }
        }

        return extras;
    }
}
