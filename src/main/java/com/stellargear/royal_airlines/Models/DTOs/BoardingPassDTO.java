package com.stellargear.royal_airlines.Models.DTOs;

import java.time.LocalDateTime;
import java.util.List;

/**
 * Vista de un pase de abordar lista para el cliente.
 *
 * @param boardingPassID identificador del pase.
 * @param passengerInfo datos del pasajero.
 * @param seats numeros de los asientos asignados.
 * @param seatClass nombre de la tarifa comprada.
 * @param gate puerta de embarque asignada.
 * @param group grupo de embarque.
 * @param flightNumber numero de vuelo.
 * @param airline compania aerea.
 * @param departureIataCode codigo IATA del aeropuerto de salida.
 * @param arrivalIataCode codigo IATA del aeropuerto de llegada.
 * @param departureDate fecha y hora de salida.
 */
public record BoardingPassDTO(
        String boardingPassID,
        String passengerInfo,
        List<String> seats,
        String seatClass,
        String gate,
        String group,
        String flightNumber,
        String airline,
        String departureIataCode,
        String arrivalIataCode,
        LocalDateTime departureDate
) {}