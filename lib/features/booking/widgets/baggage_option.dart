/// BaggageOption
/// -------------
/// Opciones de equipaje adicional disponibles en el checkout.
enum BaggageOption { included, extra10kg, extra20kg }

/// Precio adicional de cada [BaggageOption], y su etiqueta legible.
/// Valores en pesos colombianos (COP), consistentes con el resto de
/// la app (tarifas de vuelo y cargos de asiento).
extension BaggageOptionInfo on BaggageOption {
  String get label {
    switch (this) {
      case BaggageOption.included:
        return 'Equipaje incluido';
      case BaggageOption.extra10kg:
        return '+10 kg extra';
      case BaggageOption.extra20kg:
        return '+20 kg extra';
    }
  }

  double get price {
    switch (this) {
      case BaggageOption.included:
        return 0;
      case BaggageOption.extra10kg:
        return 15000;
      case BaggageOption.extra20kg:
        return 30000;
    }
  }

  /// Etiqueta enviada en `extras` al crear la reserva
  /// (`POST /booking/create` espera una LISTA de strings cortos). El
  /// equipaje incluido no genera extra, por eso se filtra el vacío en
  /// [LegBooking.bookingExtras].
  String get extraTag {
    switch (this) {
      case BaggageOption.included:
        return '';
      case BaggageOption.extra10kg:
        return 'BAGGAGE_EXTRA_10KG';
      case BaggageOption.extra20kg:
        return 'BAGGAGE_EXTRA_20KG';
    }
  }
}
