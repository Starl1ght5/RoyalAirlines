import 'package:flutter/foundation.dart';
import 'package:royal_airlines/features/reservations/repository/reservations_storage.dart';
import 'package:royal_airlines/models/reservation_model.dart';
import 'package:royal_airlines/services/reservation_service.dart';

/// ReservationsStore
/// -----------------
/// Estado GLOBAL de las reservas confirmadas por el usuario durante la
/// sesión (sincronizado por [MainNavigation]). [CheckoutScreen] escribe
/// aquí al confirmar una compra; [ReservationsScreen] y [ProfileScreen]
/// leen desde aquí para mostrar el historial y las estadísticas.
///
/// Persiste en disco vía [ReservationsStorage] (SharedPreferences como
/// JSON), asociado al `userId` de la cuenta activa: el historial
/// sobrevive a que la app se cierre por completo, se reinicie el
/// dispositivo, o el usuario cierre sesión y vuelva a entrar — NO es
/// solo un estado "Hot Reload" que se pierde apenas cambia algo. Solo
/// se descarta de memoria (nunca de disco) al cerrar sesión, para que
/// la próxima cuenta que use el dispositivo no vea reservas ajenas.
class ReservationsStore extends ChangeNotifier {
  ReservationsStore({
    ReservationsStorage? storage,
    ReservationService? reservationService,
  })  : _storage = storage ?? ReservationsStorage(),
        _reservationService = reservationService ?? ReservationService();

  final ReservationsStorage _storage;
  final ReservationService _reservationService;
  List<ReservationModel> _reservations = [];
  String? _userId;
  bool _isLoading = false;

  /// Más recientes primero.
  List<ReservationModel> get reservations {
    final sorted = [..._reservations];
    sorted.sort((a, b) => b.bookedAt.compareTo(a.bookedAt));
    return List.unmodifiable(sorted);
  }

  bool get isEmpty => _reservations.isEmpty;
  bool get isNotEmpty => _reservations.isNotEmpty;
  bool get isLoading => _isLoading;

  /// Carga el historial de reservas para [userId].
  ///
  /// La fuente de verdad es el backend (`GET /reservations` vía
  /// [ReservationService]): el historial vive en el servidor y viaja
  /// con la cuenta, no con el dispositivo. El resultado también se
  /// guarda en disco para que, si el backend queda inaccesible, la app
  /// siga mostrando el último historial conocido en vez de una
  /// pantalla vacía.
  Future<void> loadForUser(String userId) async {
    _userId = userId;
    _isLoading = true;
    notifyListeners();

    try {
      final remote = await _reservationService.fetchReservations();
      _reservations = remote;
      await _storage.save(userId, remote);
    } catch (_) {
      // Backend caído o sin conexión: se cae al historial local para
      // no dejar la pantalla en un estado irrecuperable.
      _reservations = await _storage.load(userId);
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Reconsulta el historial de la cuenta activa (pull-to-refresh).
  /// No hace nada si no hay una sesión cargada.
  Future<void> refresh() async {
    final userId = _userId;
    if (userId == null) return;
    await loadForUser(userId);
  }

  void add(ReservationModel reservation) {
    _reservations.add(reservation);
    notifyListeners();
    _persist();
  }

  /// Se llama al cerrar sesión: limpia el estado EN MEMORIA para que la
  /// próxima cuenta que use el dispositivo no vea reservas ajenas, pero
  /// el historial en disco de este usuario se conserva intacto — al
  /// volver a iniciar sesión con esta misma cuenta, [loadForUser] lo
  /// recupera de nuevo.
  void clear() {
    _reservations = [];
    _userId = null;
    notifyListeners();
  }

  void _persist() {
    final userId = _userId;
    if (userId == null) return;
    _storage.save(userId, _reservations);
  }
}
