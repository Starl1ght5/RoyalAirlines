import 'package:royal_airlines/core/network/api_client.dart';
import 'package:royal_airlines/core/network/api_contracts.dart';
import 'package:royal_airlines/models/airport_model.dart';
import 'package:royal_airlines/models/promotion_model.dart';

/// HomeRepository
/// --------------
/// Única responsable de proveer los datos que consume Home: lista de
/// aeropuertos disponibles, promociones activas y destinos populares.
/// Todo viene del backend real (`GET /locations/`, `GET /promotions`).
class HomeRepository {
  HomeRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;
  static const int _pageSize = 50;

  /// Aeropuertos disponibles para el buscador de origen/destino.
  ///
  /// El backend real tiene un solo catálogo (`/locations/`) que sirve
  /// tanto para los aeropuertos como para los destinos populares.
  Future<List<AirportModel>> getAirports() => _fetchAllLocations();

  /// Solo los destacados (featured=true) para Home.
  Future<List<AirportModel>> getPopularDestinations() =>
      _fetchAllLocations(featured: true);

  Future<List<AirportModel>> _fetchAllLocations({bool featured = false}) async {
    final all = <AirportModel>[];
    var page = 0;

    while (page < 20) {
      final response = await _apiClient.get(
        ApiEndpoints.locations,
        queryParameters: {
          'page': '$page',
          'size': '$_pageSize',
          if (featured) 'featured': 'true',
        },
      );

      final items = _airportList(_listOf(response));
      all.addAll(items);
      page++;

      final totalPages = _totalPages(response);
      final isLast =
          totalPages != null ? page >= totalPages : items.length < _pageSize;
      if (isLast || items.isEmpty) break;
    }
    return all;
  }

  static int? _totalPages(Map<String, dynamic> response) {
    final page = response['page'];
    final value =
        (page is Map ? page['totalPages'] : null) ?? response['totalPages'];
    return value is num ? value.toInt() : null;
  }

  /// Promociones activas para el slider de Home.
  Future<List<PromotionModel>> getPromotions() async {
    final response = await _apiClient.get(ApiEndpoints.promotions);
    return _promotionList(_listOf(response));
  }

  /// Saca la lista de la respuesta SIN asumir una envoltura fija.
  ///
  /// El backend real devuelve una página de Spring Data:
  /// `{content: [...], page: {...}}`. El contrato anterior de la app
  /// usaba `{data: [...]}`. Se aceptan las dos, y una lista suelta.
  ///
  /// Devolver `null` (y no una lista vacía) permite al controller
  /// distinguir "el backend no tiene aeropuertos" de "el endpoint
  /// falló": en el primer caso se muestran los que ya había.
  static Object? _listOf(Map<String, dynamic> response) {
    for (final key in const ['content', 'data', 'items']) {
      final value = response[key];
      if (value is List) return value;
    }
    return null;
  }

  List<AirportModel> _airportList(Object? data) {
    if (data is! List) return const <AirportModel>[];
    return data
        .whereType<Map<String, dynamic>>()
        .map(AirportModel.fromJson)
        .toList();
  }

  List<PromotionModel> _promotionList(Object? data) {
    if (data is! List) return const <PromotionModel>[];
    return data
        .whereType<Map<String, dynamic>>()
        .where((item) => item['active'] != false)
        .map((item) {
      final departure = item['departureDate'];
      return PromotionModel(
        title: item['title'] as String? ?? 'Promoción',
        subtitle: item['subtitle'] as String? ?? '',
        discountLabel: item['discountLabel'] as String? ?? '',
        origin: item['origin'] as String?,
        destination: item['destination'] as String?,
        // yyyy-MM-dd → DateTime (medianoche local). Un backend sin el
        // campo (o con null) deja la fecha en null, no truena.
        departureDate:
            departure is String ? DateTime.tryParse(departure) : null,
      );
    }).toList();
  }
}
