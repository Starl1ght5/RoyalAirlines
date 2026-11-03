import 'package:royal_airlines/core/network/api_client.dart';
import 'package:royal_airlines/core/network/api_contracts.dart';

/// RecommendationList
/// ------------------
/// Respuesta de `GET /api/v1/recommendations` (`RecommendationListDTO`
/// del backend), tal cual la lista el recomendador Python:
///
/// - [strategy] generó la lista: `content` | `preferences` (personalizada)
///   o `popular` | `fallback` (respaldos cuando aún no hay job);
/// - [modelVersion] versión del modelo, o `fallback-v1` sin job;
/// - [recommendationID] id de la LISTA: el front debe reenviarlo en
///   eventos (`recommendationId`) y reservas (source `RECOMMENDATION`)
///   para atribuir la conversión — NO es el id de un destino;
/// - [generatedAt] momento en que se calculó;
/// - [items] destinos ordenados por puntaje descendente.
class RecommendationList {
  const RecommendationList({
    required this.strategy,
    required this.modelVersion,
    required this.recommendationID,
    required this.generatedAt,
    required this.items,
  });

  final String strategy;
  final String modelVersion;
  final String recommendationID;
  final DateTime? generatedAt;
  final List<RecommendationListItem> items;

  factory RecommendationList.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return RecommendationList(
      strategy: json['strategy']?.toString() ?? '',
      modelVersion: json['modelVersion']?.toString() ?? '',
      recommendationID: json['recommendationID']?.toString() ?? '',
      generatedAt: _readDate(json['generatedAt']),
      items: rawItems is! List
          ? const []
          : rawItems
              .whereType<Map<String, dynamic>>()
              .map(RecommendationListItem.fromJson)
              .toList(),
    );
  }

  /// Acepta ISO "2026-10-28T03:30:00" (contrato Jackson) y fechas
  /// simples por si el formato cambia sin avisar.
  static DateTime? _readDate(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}

/// RecommendationListItem
/// ----------------------
/// Un destino recomendado con su puntaje y su explicación. Los campos
/// son tolerantes a formatos: `score` puede llegar como int/double y
/// `components`/`matchedTags`/`reasons` pueden venir vacíos (el
/// respaldo `fallback` del backend manda pocos datos).
class RecommendationListItem {
  const RecommendationListItem({
    required this.locationID,
    required this.iataCode,
    required this.cityName,
    required this.score,
    required this.components,
    required this.matchedTags,
    required this.reasons,
  });

  /// `Location.locationID` (id de MongoDB): el id REAL con el que se
  /// guardan favoritos y se atribuyen eventos.
  final String locationID;

  final String iataCode;
  final String cityName;

  /// Puntaje combinado 0-1 (ya ordenado de mayor a menor en la lista).
  final double score;

  /// Desglose por componente del recomendador: `affinity` ( afinidad
  /// de contenido), `budget`, `season`, `offer` y `fit` (ajuste al
  /// viajero). Puede venir incompleto.
  final Map<String, double> components;

  /// Etiquetas del destino que coincidieron con el perfil.
  final List<String> matchedTags;

  /// Códigos cortos del POR QUÉ aparece: `POPULAR`, `TAG_MATCH`,
  /// `IN_SEASON`, `COMPANION_FIT`, `PRICE_FITS`, `OFFER`, `FEATURED`.
  /// El mapper del front los traduce a español.
  final List<String> reasons;

  factory RecommendationListItem.fromJson(Map<String, dynamic> json) {
    return RecommendationListItem(
      locationID: json['locationID']?.toString() ?? '',
      iataCode: json['iataCode']?.toString() ?? '',
      cityName: json['cityName']?.toString() ?? '',
      score: json['score'] is num ? (json['score'] as num).toDouble() : 0,
      components: _readComponents(json['components']),
      matchedTags: _readStrings(json['matchedTags']),
      reasons: _readStrings(json['reasons']),
    );
  }

  static Map<String, double> _readComponents(Object? value) {
    if (value is! Map) return const {};
    final components = <String, double>{};
    value.forEach((key, raw) {
      if (raw is num) components[key.toString()] = raw.toDouble();
    });
    return components;
  }

  static List<String> _readStrings(Object? value) {
    if (value is! List) return const [];
    return value
        .map((element) => element?.toString() ?? '')
        .where((text) => text.isNotEmpty)
        .toList();
  }
}

/// RecommendationService
/// ---------------------
/// Lectura de `GET /recommendations` (pide JWT: sin sesión el backend
/// responde 401 y quien llame decide qué hacer).
///
/// El backend NUNCA responde "no hay recomendaciones": si el job de
/// Python no corrió devuelve la lista `__popular__` o un respaldo
/// `fallback` calculado al vuelo. Una lista vacía significaría que el
/// catálogo está vacío; el controller la trata como caso borde y cae
/// al motor local.
class RecommendationService {
  RecommendationService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<RecommendationList> fetch() async {
    // El DTO llega SIN envolver en `data` (mismo estilo que
    // `GET /users/me/preferences`): sus claves están en la raíz.
    final response = await _client.get(ApiEndpoints.recommendations);
    return RecommendationList.fromJson(response);
  }
}
