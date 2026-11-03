import 'package:flutter/foundation.dart';
import 'package:royal_airlines/features/reservations/repository/reservations_store.dart';
import 'package:royal_airlines/features/traveler_profile/repository/traveler_profile_repository.dart';
import 'package:royal_airlines/models/traveler_profile_model.dart';

/// TravelerProfileController
/// -------------------------
/// El [TravelerProfileModel] (arquetipo y métricas personales) se
/// calcula de forma SÍNCRONA: [TravelerProfileRepository.classify] solo
/// lee memoria local (`ReservationsStore`), así que no hay estado de
/// carga ni llamadas de red en este módulo.
class TravelerProfileController extends ChangeNotifier {
  TravelerProfileController({
    required ReservationsStore reservationsStore,
    TravelerProfileRepository? repository,
  })  : _reservationsStore = reservationsStore,
        _repository = repository ?? TravelerProfileRepository() {
    _recomputeProfile();
    _reservationsStore.addListener(_recomputeProfile);
  }

  final ReservationsStore _reservationsStore;
  final TravelerProfileRepository _repository;

  TravelerProfileModel _profile = TravelerProfileModel.empty();
  TravelerProfileModel get profile => _profile;

  void _recomputeProfile() {
    _profile = _repository.classify(_reservationsStore.reservations);
    notifyListeners();
  }

  /// Recalcula el perfil con las reservas más recientes: es el
  /// callback del RefreshIndicator de la pestaña "Para ti". Toda la
  /// pantalla se deriva de datos locales, así que basta con volver a
  /// correr el clasificador.
  Future<void> refresh() async {
    _recomputeProfile();
  }

  @override
  void dispose() {
    _reservationsStore.removeListener(_recomputeProfile);
    super.dispose();
  }
}
