package com.stellargear.royal_airlines.Models.DTOs;

import java.time.LocalDate;

/**
 * Promocion tal como la espera el slider de Home de Flutter (PromotionModel).
 *
 * <p>El servicio solo devuelve promociones activas, de modo que {@code active} viaja siempre en
 * {@code true}: se conserva en el shape porque el contrato documentado lo incluye y el front lo
 * revisa ({@code item['active'] != false}) antes de pintar cada tarjeta.</p>
 *
 * <p>{@code origin}, {@code destination} y {@code departureDate} son la ruta y la fecha con las
 * que el front arma la busqueda al tocar la tarjeta (fecha del vuelo mas barato de la ruta, en
 * yyyy-MM-dd). {@code departureDate} puede ser {@code null} en documentos antiguos: el front
 * entonces usa la fecha que tenga elegida en el buscador.</p>
 *
 * @param id identificador estable de la promocion.
 * @param title titulo de la tarjeta.
 * @param subtitle texto secundario de la tarjeta.
 * @param discountLabel texto del badge: porcentaje de descuento o precio desde.
 * @param origin codigo IATA del aeropuerto de salida.
 * @param destination codigo IATA del aeropuerto de llegada.
 * @param departureDate fecha del vuelo mas barato de la ruta, en formato {@code yyyy-MM-dd}.
 * @param active indica si la promocion debe mostrarse; siempre {@code true} en la respuesta.
 */
public record PromotionDTO(
    String id,
    String title,
    String subtitle,
    String discountLabel,
    String origin,
    String destination,
    LocalDate departureDate,
    boolean active) {
}
