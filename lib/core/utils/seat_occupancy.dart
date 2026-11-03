/// SeatOccupancy
/// -------------
/// Calcula, de forma determinística a partir del ID del vuelo, qué
/// asientos están ocupados en el mapa de sillas ([SeatSelector]) y qué
/// tan lleno está el vuelo en general ([FlightModel.demandForecast]).
///
/// Se centraliza aquí para que el mapa de asientos que el usuario ve
/// al elegir silla y el porcentaje de "probabilidad de llenarse" que
/// se muestra en los resultados de búsqueda usen EXACTAMENTE el mismo
/// cálculo — así nunca quedan desconectados entre sí.
class SeatOccupancy {
  const SeatOccupancy._();

  /// Porcentaje de ocupación propio de cada vuelo (varía entre 20% y
  /// 95% según su [flightId], para que unos vuelos se vean casi
  /// vacíos y otros casi llenos, de forma realista).
  static double occupancyRatioFor(String flightId) {
    final seed = flightId.hashCode.abs();
    return 0.20 + (seed % 76) / 100.0;
  }

  /// Set de códigos de asiento ocupados (ej. "3A") para un vuelo,
  /// dado el tamaño del mapa (columnas x filas).
  static Set<String> occupiedSeatsFor(
    String flightId,
    int rowCount,
    List<String> columns,
  ) {
    final seed = flightId.hashCode.abs();
    final threshold = (occupancyRatioFor(flightId) * 100).round();

    final occupied = <String>{};
    for (var row = 1; row <= rowCount; row++) {
      for (var column = 0; column < columns.length; column++) {
        if ((seed + row * 37 + column * 53) % 100 < threshold) {
          occupied.add('$row${columns[column]}');
        }
      }
    }
    return occupied;
  }
}
