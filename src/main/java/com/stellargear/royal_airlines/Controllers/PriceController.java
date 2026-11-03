package com.stellargear.royal_airlines.Controllers;

import com.stellargear.royal_airlines.Models.DTOs.PricePointDTO;
import com.stellargear.royal_airlines.Services.PriceSnapshotService;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

/**
 * Expone el historial de precios de una ruta.
 *
 * <p>Requiere token ({@code anyRequest().authenticated()}). Los precios viajan en USD, como se
 * guardan en la base.</p>
 */
@RestController
@RequiredArgsConstructor
@RequestMapping(path = "/api/v1/prices")
public class PriceController {

  private final PriceSnapshotService priceService;

  /**
   * Lista las fotos diarias de precio de una ruta para una fecha de salida.
   *
   * <p>Ejemplo: {@code GET /api/v1/prices/history?origin=BOG&destination=MDE&departureDate=2026-12-20&days=30}.</p>
   *
   * @param origin codigo IATA del aeropuerto de salida.
   * @param destination codigo IATA del aeropuerto de llegada.
   * @param departureDate fecha de salida, en formato {@code yyyy-MM-dd}.
   * @param days ventana de dias hacia atras; se acota entre 1 y 180.
   * @return puntos de precio en orden cronologico.
   */
  @GetMapping("/history")
  public List<PricePointDTO> history(@RequestParam String origin, @RequestParam String destination,
                                     @RequestParam String departureDate,
                                     @RequestParam(defaultValue = "30") int days) {
    return priceService.history(origin, destination, departureDate, Math.max(1, Math.min(days, 180)));
  }
}
