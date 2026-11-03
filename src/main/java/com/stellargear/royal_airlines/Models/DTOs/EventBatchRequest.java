package com.stellargear.royal_airlines.Models.DTOs;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.time.Instant;
import java.util.List;
import java.util.Map;

/**
 * Lote de eventos de comportamiento enviado por la app.
 *
 * @param events eventos del lote, hasta cincuenta.
 */
public record EventBatchRequest(@NotEmpty @Size(max = 50) List<@Valid EventDto> events) {

  /**
   * Evento individual del lote.
   *
   * @param clientEventId identificador generado por el cliente para deduplicar reintentos.
   * @param type tipo de evento permitido por el servidor.
   * @param ts momento en que ocurrio el evento.
   * @param sessionId sesion del cliente, si aplica.
   * @param destinationId destino relacionado con el evento.
   * @param flightId vuelo relacionado con el evento.
   * @param recommendationId recomendacion relacionada con el evento.
   * @param position posicion del elemento dentro de una lista.
   * @param context pantalla o contexto donde ocurrio el evento.
   * @param payload datos adicionales del evento.
   */
  public record EventDto(
      @NotBlank @Size(max = 64) String clientEventId,
      @NotBlank @Size(max = 40) String type,
      @NotNull Instant ts,
      @Size(max = 64) String sessionId,
      @Size(max = 64) String destinationId,
      @Size(max = 64) String flightId,
      @Size(max = 64) String recommendationId,
      @Min(0) @Max(100) Integer position,
      @Size(max = 32) String context,
      @Size(max = 20) Map<String, String> payload) {}

  /**
   * Resumen del procesamiento del lote.
   *
   * @param accepted eventos guardados o ya existentes.
   * @param rejected eventos descartados por tipo o payload invalido.
   * @param trackingEnabled indica si el usuario tiene el seguimiento activo.
   */
  public record Result(int accepted, int rejected, boolean trackingEnabled) {}
}
