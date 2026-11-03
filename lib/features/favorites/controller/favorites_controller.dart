import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:royal_airlines/core/network/api_client.dart';
import 'package:royal_airlines/features/home/repository/home_repository.dart';
import 'package:royal_airlines/models/airport_model.dart';
import 'package:royal_airlines/services/favorites_service.dart';

enum FavoritesStatus { idle, loading, success, error }

/// FavoritesController
/// -------------------
/// Estado global de los favoritos del usuario (`GET`/`POST`/`DELETE
/// /favorites`). Se registra en `lib/app.dart` y se carga al arrancar
/// la sesión (puerta en `_AuthGate`), para que los corazones de
/// cualquier pantalla empiecen con el estado real del servidor.
///
/// Los toggles son OPTIMISTAS: el corazón cambia de inmediato y, si
/// el backend responde con `ApiException` (404 porque el id no existe,
/// 409 por pasar de 200 favoritos, sin red...), se revierte y se
/// devuelve el mensaje para que la UI lo muestre.
///
/// OJO: aquí NO se llama a `UserEventTracker.track()`. Los eventos
/// `favorite_add` / `favorite_remove` los emite EL SERVIDOR (con
/// `context: "favorites"` y solo si hay consentimiento de tracking);
/// enviarlos del cliente sería duplicado y el backend los rechaza.
///
/// Además carga el catálogo `GET /locations/` en segundo plano, porque
/// los corazones de destinos pueden llegar identificados solo por su
/// código IATA (tarjetas de recomendaciones) y el backend exige el
/// `Location.locationID` real: sin el catálogo no hay forma de saberlo.
class FavoritesController extends ChangeNotifier {
  FavoritesController({
    FavoritesService? service,
    HomeRepository? repository,
  })  : _service = service ?? FavoritesService(),
        _repository = repository ?? HomeRepository();

  final FavoritesService _service;
  final HomeRepository _repository;

  FavoritesStatus _status = FavoritesStatus.idle;
  String? _errorMessage;
  List<FavoriteItem> _items = const [];

  Map<String, String> _locationIdByCode = const {};
  Map<String, AirportModel> _airportByLocationId = const {};
  bool _isLoadingCatalog = false;

  bool _disposed = false;

  FavoritesStatus get status => _status;
  String? get errorMessage => _errorMessage;

  /// Orden igual que el backend: por fecha de creación descendente.
  List<FavoriteItem> get items => _items;
  int get count => _items.length;
  bool get isLoading => _status == FavoritesStatus.loading;

  /// `true` cuando el catálogo ya se cargó (los corazones de destinos
  /// que vienen solo con IATA dependen de esto).
  bool get isCatalogLoaded => _locationIdByCode.isNotEmpty;

  bool isFavorite(FavoriteTarget targetType, String targetId) {
    if (targetId.isEmpty) return false;
    return _items.any(
        (item) => item.targetType == targetType && item.targetId == targetId);
  }

  /// `Location.locationID` de un destino: usa el id si ya viene en la
  /// tarjeta y, si solo hay código IATA, lo resuelve con el catálogo.
  String? resolveLocationId(String code, {String? hint}) {
    if (hint != null && hint.isNotEmpty) return hint;
    if (code.isEmpty) return null;
    return _locationIdByCode[code];
  }

  /// Datos del catálogo para mostrar un destino guardado (la lista de
  /// "Guardados" solo recibe `targetId`, no la ciudad).
  AirportModel? airportFor(String locationId) =>
      _airportByLocationId[locationId];

  /// `GET /favorites` (+ catálogo en paralelo, mejor esfuerzo).
  /// Nunca lanza: los errores quedan en [status]/[errorMessage].
  Future<void> load() async {
    if (_status == FavoritesStatus.loading) return;

    _status = FavoritesStatus.loading;
    _errorMessage = null;
    _notify();

    try {
      _items = await _service.list();
      _status = FavoritesStatus.success;
    } catch (error) {
      _status = FavoritesStatus.error;
      _errorMessage = error is ApiException
          ? error.message
          : 'No se pudieron cargar tus favoritos. Intenta de nuevo.';
    }
    _notify();

    unawaited(_loadCatalog());
  }

  /// Alterna el favorito de forma OPTIMISTA. Devuelve `null` si todo
  /// quedó bien o el mensaje de error si hubo que revertir el cambio.
  Future<String?> toggle(FavoriteTarget targetType, String targetId) async {
    if (targetId.isEmpty) {
      return 'Este destino aún no está disponible para guardar.';
    }

    final wasFavorite = isFavorite(targetType, targetId);
    _setFavorite(targetType, targetId, !wasFavorite);

    try {
      if (wasFavorite) {
        await _service.remove(targetType, targetId);
      } else {
        await _service.add(targetType, targetId);
      }
      return null;
    } catch (error) {
      // Rollback: el servidor no aceptó el cambio, el corazón vuelve
      // a como estaba y la UI avisa.
      _setFavorite(targetType, targetId, wasFavorite);
      _errorMessage = error is ApiException
          ? error.message
          : 'No se pudo actualizar tu favorito. Intenta de nuevo.';
      return _errorMessage;
    }
  }

  /// Limpia los datos de la cuenta anterior al cerrar sesión. El
  /// catálogo se conserva (no es dato de usuario y evita un GET más).
  void clear() {
    _items = const [];
    _status = FavoritesStatus.idle;
    _errorMessage = null;
    _notify();
  }

  void _setFavorite(FavoriteTarget targetType, String targetId, bool value) {
    final next = List<FavoriteItem>.from(_items);
    next.removeWhere(
        (item) => item.targetType == targetType && item.targetId == targetId);
    if (value) {
      next.insert(0, FavoriteItem(targetType: targetType, targetId: targetId));
    }
    _items = next;
    _notify();
  }

  Future<void> _loadCatalog() async {
    if (_isLoadingCatalog) return;
    _isLoadingCatalog = true;
    try {
      final airports = await _repository.getAirports();
      _locationIdByCode = {
        for (final airport in airports)
          if (airport.code.isNotEmpty && airport.locationId != null)
            airport.code: airport.locationId!,
      };
      _airportByLocationId = {
        for (final airport in airports)
          if (airport.locationId != null) airport.locationId!: airport,
      };
    } catch (_) {
      // Sin catálogo los corazones que vienen solo con IATA quedan en
      // "sin resolver" (inactivos), no se rompe nada.
    } finally {
      _isLoadingCatalog = false;
      _notify();
    }
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
