package com.stellargear.royal_airlines.Models.Entities;

import java.time.Instant;
import java.time.LocalDate;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

/**
 * Promocion del slider de Home, generada automaticamente a partir de los vuelos proximos.
 *
 * <p>El front pinta {@code title}, {@code subtitle} y {@code discountLabel} y descarta las
 * promociones que llegan con {@code active=false}. {@code origin}, {@code destination} y
 * {@code departureDate} viajan en el documento para que al tocar la tarjeta el slider pueda
 * navegar directo a los vuelos de esa ruta: {@code departureDate} es la fecha (yyyy-MM-dd) del
 * vuelo mas barato de la ruta, que es el que publica el precio, de modo que la busqueda siempre
 * aterriza en un dia con vuelos reales. Puede ser {@code null} en documentos escritos antes de
 * este campo: el front entonces cae a la fecha que tenga elegida en el buscador.</p>
 *
 * <p>{@code generatedAt} es la huella del calculo: {@code PromotionService} regenera la coleccion
 * cuando alguno de estos documentos tiene mas de 6 horas (o no tiene la marca). Para ocultar una
 * promocion se pone {@code active=false}: el refresh conserva ese campo manual.</p>
 *
 * @param id identificador estable derivado de la ruta.
 * @param title titulo de la tarjeta.
 * @param subtitle texto secundario de la tarjeta.
 * @param discountLabel texto del badge: descuento o precio desde.
 * @param origin codigo IATA del aeropuerto de salida.
 * @param destination codigo IATA del aeropuerto de llegada.
 * @param departureDate fecha del vuelo ancla de la tarjeta.
 * @param active indica si la promocion se muestra en el slider.
 * @param sortOrder posicion en el slider, empezando en 1.
 * @param generatedAt momento del ultimo calculo desde los vuelos.
 */
@Document(collection = "Promotions")
public record Promotion(
    @Id String id,
    String title,
    String subtitle,
    String discountLabel,
    String origin,
    String destination,
    LocalDate departureDate,
    boolean active,
    int sortOrder,
    Instant generatedAt) {
}
