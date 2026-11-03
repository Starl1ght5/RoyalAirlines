/// SeatCategory
/// ------------
/// Zona/categoría del asiento según su ubicación en la cabina. Las
/// filas delanteras (más cerca de la salida) cuestan más que las de
/// atrás, igual que en la mayoría de aerolíneas reales.
enum SeatCategory { preferente, estandarPlus, estandar }

extension SeatCategoryInfo on SeatCategory {
  String get label {
    switch (this) {
      case SeatCategory.preferente:
        return 'Preferente';
      case SeatCategory.estandarPlus:
        return 'Estándar Plus';
      case SeatCategory.estandar:
        return 'Estándar';
    }
  }

  /// Precio del cargo por asiento, en pesos colombianos (COP).
  int get price {
    switch (this) {
      case SeatCategory.preferente:
        return 95000;
      case SeatCategory.estandarPlus:
        return 68000;
      case SeatCategory.estandar:
        return 46000;
    }
  }
}

/// SeatPricing
/// -----------
/// Única responsable de calcular la categoría/precio de un asiento a
/// partir de su fila. Es un mapeo puramente por ubicación (no depende
/// del vuelo ni de si está ocupado), así que tanto [SeatSelector] como
/// [TripBookingController] pueden usar esta misma fuente de verdad sin
/// duplicar la lógica de precios.
class SeatPricing {
  SeatPricing._();

  /// Filas 1-3: Preferente. Filas 4-7: Estándar Plus. Filas 8-15: Estándar.
  static SeatCategory categoryForRow(int row) {
    if (row <= 3) return SeatCategory.preferente;
    if (row <= 7) return SeatCategory.estandarPlus;
    return SeatCategory.estandar;
  }

  /// Extrae el número de fila desde un código de asiento como "13B".
  static int rowFromSeatCode(String seatCode) {
    final match = RegExp(r'^\d+').firstMatch(seatCode);
    return int.tryParse(match?.group(0) ?? '') ?? 1;
  }

  static SeatCategory categoryForSeat(String seatCode) =>
      categoryForRow(rowFromSeatCode(seatCode));
}
