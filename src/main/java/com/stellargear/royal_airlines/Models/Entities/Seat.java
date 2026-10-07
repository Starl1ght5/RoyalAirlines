package com.stellargear.royal_airlines.Models.Entities;

import lombok.Getter;
import lombok.Setter;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

/**
 * Asiento de un vuelo.
 *
 * <p>La marca {@code reserved} cubre tanto los asientos ya vendidos como los retenidos
 * temporalmente por una reserva pendiente.</p>
 */
@Setter
@Getter
@Document(collection = "Seats")
public class Seat {

    @Id
    private String seatID;

    private String seatNumber;
    private double seatPrice;
    private boolean reserved;

    /** Crea el asiento vacio para que el generador asigne sus campos. */
    public Seat() {}
}