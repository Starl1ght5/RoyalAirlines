import 'package:royal_airlines/models/seat_pricing.dart';

/// SeatMapCategory
/// ---------------
/// Zona de la cabina tal como la describe el backend en
/// `SeatMapDTO.CategoryDTO`: su nombre (`PREFERENTE` | `PLUS` |
/// `ESTANDAR`), el rango de filas que cubre y el precio del asiento en
/// pesos colombianos (el backend lo convierte desde USD). El precio
/// real del vuelo manda sobre el tarifario local de [SeatPricing].
class SeatMapCategory {
  final SeatCategory category;
  final int fromRow;
  final int toRow;
  final double price;

  const SeatMapCategory({
    required this.category,
    required this.fromRow,
    required this.toRow,
    required this.price,
  });

  bool containsRow(int row) => row >= fromRow && row <= toRow;

  factory SeatMapCategory.fromJson(Map<String, dynamic> json) {
    return SeatMapCategory(
      category: _seatCategoryFrom(json['category']),
      fromRow: (json['fromRow'] as num?)?.toInt() ?? 1,
      toRow: (json['toRow'] as num?)?.toInt() ?? 1,
      price: _moneyCopFrom(json['price']),
    );
  }
}

/// SeatMapModel
/// -------------
/// Mapa de asientos de UN vuelo, tal como lo sirve
/// `GET /flights/{flightId}/seats` (ruta pública): la cabina es fija
/// (15 filas × A–F = 90 asientos) y la ocupación real vive en el vuelo.
///
/// `takenSeats` incluye asientos RETENIDOS (reservas `PENDING`) y
/// confirmados: ninguno de los dos se puede elegir. Si mientras el
/// usuario elegía alguien tomó su asiento, la creación de la reserva
/// falla con 409 y hay que recargar este mapa.
class SeatMapModel {
  final String flightId;
  final int rows;
  final List<String> columns;
  final List<SeatMapCategory> categories;
  final List<int> extraLegroomRows;

  /// Códigos ocupados o retenidos, ej. "12B".
  final Set<String> takenSeats;

  /// Asientos libres de la cabina.
  final int seatsLeft;

  const SeatMapModel({
    required this.flightId,
    required this.rows,
    required this.columns,
    required this.categories,
    required this.extraLegroomRows,
    required this.takenSeats,
    required this.seatsLeft,
  });

  factory SeatMapModel.fromJson(Map<String, dynamic> json) {
    final columns = (json['columns'] as List? ?? const [])
        .map((column) => column.toString().toUpperCase())
        .toList();
    final takenSeats = (json['takenSeats'] as List? ?? const [])
        .map((seat) => seat.toString().toUpperCase())
        .toList();
    final rows = (json['rows'] as num?)?.toInt() ?? 15;

    return SeatMapModel(
      flightId: json['flightID'] as String? ?? '',
      rows: rows,
      // La cabina del MVP es siempre A–F; el default evita un mapa
      // degenerado si un día el backend omitiera la lista.
      columns: columns.isEmpty ? const ['A', 'B', 'C', 'D', 'E', 'F'] : columns,
      categories: (json['categories'] as List? ?? const [])
          .whereType<Map>()
          .map((category) =>
              SeatMapCategory.fromJson(category.cast<String, dynamic>()))
          .toList(),
      extraLegroomRows: (json['extraLegroomRows'] as List? ?? const [])
          .map((row) => (row as num).toInt())
          .toList(),
      takenSeats: takenSeats.toSet(),
      seatsLeft: (json['seatsLeft'] as num?)?.toInt() ??
          rows * (columns.isEmpty ? 6 : columns.length) - takenSeats.length,
    );
  }

  bool isTaken(String seatCode) => takenSeats.contains(seatCode.toUpperCase());

  bool hasExtraLegroom(int row) => extraLegroomRows.contains(row);

  /// Zona que cubre una fila según los rangos del backend. Si el mapa
  /// no trae categorías (respuesta incompleta) se cae al tarifario
  /// local de [SeatPricing] para no dejar la UI sin precios.
  SeatMapCategory categoryForRow(int row) {
    for (final category in categories) {
      if (category.containsRow(row)) return category;
    }
    final fallback = SeatPricing.categoryForRow(row);
    return SeatMapCategory(
      category: fallback,
      fromRow: row,
      toRow: row,
      price: fallback.price.toDouble(),
    );
  }

  SeatMapCategory categoryForSeat(String seatCode) =>
      categoryForRow(SeatPricing.rowFromSeatCode(seatCode));

  /// Precio en COP del asiento, según su categoría en este vuelo.
  double priceForSeat(String seatCode) => categoryForSeat(seatCode).price;
}

/// Convierte el nombre de categoría del backend (`PREFERENTE`, `PLUS`,
/// `ESTANDAR`) a la zona equivalente de la UI ([SeatCategory]).
SeatCategory _seatCategoryFrom(Object? value) {
  final raw = value?.toString().toUpperCase() ?? '';
  switch (raw) {
    case 'PREFERENTE':
      return SeatCategory.preferente;
    case 'PLUS':
      return SeatCategory.estandarPlus;
    case 'ESTANDAR':
      return SeatCategory.estandar;
    default:
      return SeatCategory.estandar;
  }
}

/// Lee un importe `Money` (Joda) del backend como número en COP;
/// tolera también un número plano.
double _moneyCopFrom(Object? value) {
  if (value is num) return value.toDouble();
  if (value is Map) {
    final major = value['amountMajor'];
    if (major is num) return major.toDouble();
    final amount = value['amount'];
    if (amount is num) return amount.toDouble();
  }
  return 0;
}
