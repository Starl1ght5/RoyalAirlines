package com.stellargear.royal_airlines.Controllers;

import com.stellargear.royal_airlines.Models.DTOs.BookingDTO;
import com.stellargear.royal_airlines.Models.DTOs.CreateBookingRequest;
import com.stellargear.royal_airlines.Models.Utils.UserPrincipal;
import com.stellargear.royal_airlines.Services.BookingService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Gestiona el ciclo de vida de las reservas: creacion, consulta, confirmacion y cancelacion.
 */
@RestController
@RequiredArgsConstructor
@RequestMapping(path = "/api/v1/booking")
public class BookingController {

    private final BookingService bookingService;

    /**
     * Crea una reserva en estado pendiente y bloquea los asientos elegidos.
     *
     * @param request vuelo, tarifa y asientos a reservar.
     * @param principal usuario extraido del token JWT.
     * @return identificador de la reserva creada.
     */
    @PostMapping(path = "/create")
    @ResponseStatus(HttpStatus.CREATED)
    public String bookNewFlight(@Valid @RequestBody CreateBookingRequest request,
                                @AuthenticationPrincipal UserPrincipal principal) {
        return bookingService.bookFlight(request, principal.getUserID());
    }

    /**
     * Consulta una reserva propia.
     *
     * @param id identificador de la reserva.
     * @param principal usuario extraido del token JWT.
     * @return datos de la reserva.
     */
    @GetMapping(path = "/{id}")
    public BookingDTO getBookingInfo(@PathVariable String id,
                                     @AuthenticationPrincipal UserPrincipal principal) {
        return bookingService.searchAndReturnObject(id, principal.getUserID());
    }

    /**
     * Confirma una reserva pendiente y emite su pase de abordar.
     *
     * @param id identificador de la reserva a confirmar.
     * @param principal usuario extraido del token JWT.
     */
    @PatchMapping(path = "/confirm")
    public void confirmBooking(@RequestParam @NotBlank String id,
                               @AuthenticationPrincipal UserPrincipal principal) {
        bookingService.confirmBooking(id, principal.getUserID());
    }

    /**
     * Cancela una reserva pendiente o confirmada y libera sus asientos.
     *
     * @param id identificador de la reserva a cancelar.
     * @param principal usuario extraido del token JWT.
     */
    @PatchMapping(path = "/cancel")
    public void cancelBooking(@RequestParam @NotBlank String id,
                              @AuthenticationPrincipal UserPrincipal principal) {
        bookingService.cancelBooking(id, principal.getUserID());
    }
}