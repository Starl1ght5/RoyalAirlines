import 'package:royal_airlines/core/network/api_client.dart';
import 'package:royal_airlines/core/network/api_contracts.dart';

/// PriceSnapshot
/// -------------
/// Un punto del histórico de precios de una ruta: el precio mínimo
/// (en **USD**, única moneda de esta ruta en toda la app) registrado
/// en [capturedDate] y cuántos vuelos se miraron ese día.
class PriceSnapshot {
  const PriceSnapshot({
    required this.capturedDate,
    required this.minPriceUsd,
    required this.flightsCount,
  });

  /// Día en que corrió la tarea del backend (03:30).
  final DateTime capturedDate;

  /// Precio mínimo de la ruta ese día, en USD.
  final double minPriceUsd;

  /// Vuelos considerados ese día (0 = el día no aportó datos).
  final int flightsCount;

  factory PriceSnapshot.fromJson(Map<String, dynamic> json) {
    return PriceSnapshot(
      capturedDate: _readDate(json['capturedDate']) ?? DateTime(2000),
      minPriceUsd: json['minPriceUsd'] is num
          ? (json['minPriceUsd'] as num).toDouble()
          : 0,
      flightsCount: json['flightsCount'] is num
          ? (json['flightsCount'] as num).toInt()
          : 0,
    );
  }

  static DateTime? _readDate(Object? value) {
    if (value is! String || value.isEmpty) return null;
    // Acepta "2026-10-28" (contrato) y "2026-10-28T03:30:00" por si el
    // backend algún día cambia el formato sin avisar.
    return DateTime.tryParse(value);
  }
}

/// PriceHistoryService
/// -------------------
/// Lectura de `GET /prices/history?origin=&destination=&departureDate
/// =&days=` (1..180, por defecto 30).
///
/// Es la ÚNICA ruta en USD de la app: `minPriceUsd` viene en dólares y
/// la UI debe etiquetarlo como tal (nunca convertirlo a COP sin una
/// tasa conocida).
///
/// Solo LECTURA: los snapshots los escribe la tarea programada del
/// backend (03:30), no existe endpoint de escritura. Una ruta sin
/// datos devuelve `[]` (eso NO es error: la UI muestra "aún no hay
/// historial").
class PriceHistoryService {
  PriceHistoryService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  /// Historial de la ruta [origin] → [destination] para la salida
  /// [departureDate] en los últimos [days] días (se recorta al rango
  /// 1-180 que acepta el backend).
  ///
  /// La lista sale ORDENADA por fecha ascendente, que es como la
  /// gráfica la necesita.
  Future<List<PriceSnapshot>> fetch({
    required String origin,
    required String destination,
    required DateTime departureDate,
    int days = 90,
  }) async {
    if (origin.isEmpty || destination.isEmpty) return const [];

    final response = await _client.get(
      ApiEndpoints.priceHistory,
      queryParameters: {
        'origin': origin,
        'destination': destination,
        'departureDate': _queryDate(departureDate),
        'days': days.clamp(1, 180).toString(),
      },
    );

    final data = response['data'];
    if (data is! List) return const [];

    final snapshots = data
        .whereType<Map<String, dynamic>>()
        .map(PriceSnapshot.fromJson)
        .toList()
      ..sort((a, b) => a.capturedDate.compareTo(b.capturedDate));
    return snapshots;
  }

  /// `yyyy-MM-dd` (formato de fecha del contrato del backend).
  static String _queryDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
