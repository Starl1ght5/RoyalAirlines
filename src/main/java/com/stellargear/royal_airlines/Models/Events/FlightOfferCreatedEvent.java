package com.stellargear.royal_airlines.Models.Events;

/** Se publica despues de guardar un vuelo con oferta. Solo lleva el id: el listener recarga. */
public record FlightOfferCreatedEvent(String flightId) {}
