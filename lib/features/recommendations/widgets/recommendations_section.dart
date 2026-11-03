import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:royal_airlines/core/theme/app_colors.dart';
import 'package:royal_airlines/core/theme/app_spacing.dart';
import 'package:royal_airlines/core/theme/app_theme.dart';
import 'package:royal_airlines/features/auth/controller/auth_controller.dart';
import 'package:royal_airlines/features/recommendations/controller/recommendation_controller.dart';
import 'package:royal_airlines/features/recommendations/widgets/comparison_radar.dart';
import 'package:royal_airlines/features/recommendations/widgets/destination_match_sheet.dart';
import 'package:royal_airlines/features/recommendations/widgets/recommendation_card.dart';
import 'package:royal_airlines/features/reservations/repository/reservations_store.dart';
import 'package:royal_airlines/features/traveler_profile/controller/traveler_preferences_controller.dart';
import 'package:royal_airlines/features/traveler_profile/widgets/preferences_sheet.dart';
import 'package:royal_airlines/models/recommendation_model.dart';
import 'package:royal_airlines/models/traveler_preferences_model.dart';
import 'package:royal_airlines/services/recommendation_service.dart';
import 'package:royal_airlines/services/user_event_tracker.dart';
import 'package:royal_airlines/shared/widgets/custom_button.dart';

/// RecommendationsSection
/// ----------------------
/// Sección "Recomendado para ti" dentro de la pestaña "Para ti"
/// (Etapa C del motor de recomendaciones). Observa las preferencias
/// declaradas (Etapa A), el historial de reservas y la SESIÓN, pide la
/// lista al backend (`GET /recommendations`, con el motor local como
/// respaldo silencioso) y lista las N mejores tarjetas; al tocar una
/// abre [DestinationMatchSheet].
///
/// Estados:
/// - Sin preferencias → CTA para completarlas (el motor no tiene con
///   qué casar el catálogo).
/// - Con preferencias → tarjetas con % de afinidad (cargando de fondo
///   la lista remota si hay sesión).
class RecommendationsSection extends StatefulWidget {
  const RecommendationsSection({super.key});

  @override
  State<RecommendationsSection> createState() => _RecommendationsSectionState();
}

class _RecommendationsSectionState extends State<RecommendationsSection> {
  // Servicio remoto inyectado: sin backend (tests) el controller cae
  // al motor local automáticamente.
  final _controller = RecommendationController(
    service: RecommendationService(),
  );

  // Firma del último input con el que se calculó el motor. Evita el
  // loop infinito build -> postFrameCallback -> rebuild -> notify ->
  // setState -> build... recalculando solo cuando algo cambió de verdad.
  TravelerPreferencesModel? _lastPreferences;
  int _lastRevision = 0;
  String _lastVisitedKey = '';
  String _lastSessionKey = '';

  @override
  void initState() {
    super.initState();
    // El motor vive como campo local (no como provider), así que este
    // listener es el que traduce notifyListeners() en un setState que
    // redibuje las tarjetas cuando cambia el ranking.
    _controller.addListener(_onEngineChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onEngineChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onEngineChanged() {
    if (mounted) setState(() {});
  }

  void _rebuild() {
    final preferencesController = context.read<TravelerPreferencesController>();
    final reservationsStore = context.read<ReservationsStore>();
    final authController = context.read<AuthController>();

    final preferences = preferencesController.preferences;
    final visitedKey = reservationsStore.reservations
        .map((reservation) => reservation.flight.destination.city)
        .join('|');
    // Cambiar de cuenta (o entrar/salir) debe re-pedir la lista: cada
    // usuario tiene la SUYA en el backend.
    final sessionKey = authController.isAuthenticated
        ? (authController.currentUser?.id ?? 'auth')
        : 'anon';
    // La revisión solo cambia cuando el SERVIDOR confirmó datos nuevos
    // (PUT de preferencias exitoso o adopción de lo remoto): es la señal
    // de que vale la pena pedir la lista fresca. Un guardar sin cambios
    // no la mueve, así que no se dispara ningún refresh.
    final revision = preferencesController.revision;

    // Mientras el PUT está en vuelo el backend aún no tiene el perfil
    // nuevo (puede estar invalidando/recalculando): pedir la lista AHORA
    // devolvería la versión vieja. Se sale SIN actualizar la firma para
    // que el notify del push (revision++ ) reintente en el siguiente
    // frame y ahí sí se cargue lo recién calculado.
    if (preferencesController.isPushInFlight) return;

    if (identical(preferences, _lastPreferences) &&
        revision == _lastRevision &&
        visitedKey == _lastVisitedKey &&
        sessionKey == _lastSessionKey) {
      return;
    }
    _lastPreferences = preferences;
    _lastRevision = revision;
    _lastVisitedKey = visitedKey;
    _lastSessionKey = sessionKey;

    final visited =
        visitedKey.isEmpty ? const <String>[] : visitedKey.split('|');

    // Remoto solo con sesión JWT (la ruta pide autenticación) Y
    // preferencias locales declaradas (sin ellas la UI muestra el CTA
    // y no hay nada que casar). Sin sesión → motor local al instante.
    if (authController.isAuthenticated && preferences.hasPreferences) {
      unawaited(
        _controller.loadRemote(
          preferences: preferences,
          visitedCities: visited,
        ),
      );
    } else {
      _controller.rebuild(
        preferences: preferences,
        visitedCities: visited,
      );
    }
  }

  /// Abre el análisis del destino y registra las dos señales que le
  /// interesan al recomendador: que se TOCÓ la recomendación
  /// (`recommendation_click`) y que se CERRÓ sin reservar
  /// (`recommendation_dismiss` — el sheet devuelve `'booked'` cuando
  /// el usuario sigue el CTA, y en ese caso NO se cuenta como
  /// descarte).
  ///
  /// `recommendationId` es el id de la LISTA del backend
  /// (`recommendationID`), que es lo que permite atribuir la
  /// conversión a la lista que generó el click; `destinationId` lleva
  /// el id real del destino (`Location.locationID`, con el IATA como
  /// respaldo en modo motor local).
  Future<void> _openMatchSheet(
    BuildContext context,
    RecommendationResult result,
    int position,
  ) async {
    final tracker = context.read<UserEventTracker>();
    // Se capturan ANTES del await: el sheet puede tardar y el
    // controller podría refrescarse (otra sesión, nuevas reservas).
    final listId = _listId(result);
    final destinationId = _destinationId(result);

    tracker.track(
      'recommendation_click',
      destinationId: destinationId,
      recommendationId: listId,
      position: position,
      context: 'recommendations',
    );

    final outcome = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (_) => DestinationMatchSheet(result: result),
    );

    if (!mounted) return;
    if (outcome == null) {
      // Se reutiliza la referencia capturada ANTES del await: usar
      // `context` aquí dispararía el lint de context tras async gap.
      tracker.track(
        'recommendation_dismiss',
        destinationId: destinationId,
        recommendationId: listId,
        position: position,
        context: 'recommendations',
      );
    }
  }

  /// Id de la LISTA para los eventos: el `recommendationID` real del
  /// backend cuando la lista vino de `GET /recommendations`; el código
  /// IATA como referencia cuando el ranking es del motor local.
  String _listId(RecommendationResult result) =>
      _controller.recommendationId ?? result.destination.code;

  /// Id del DESTINO para los eventos: `Location.locationID` cuando la
  /// lista vino del backend; el IATA como respaldo en modo local.
  static String _destinationId(RecommendationResult result) =>
      result.locationId ?? result.destination.code;

  void _openPreferencesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (_) => PreferencesSheet(
        controller: context.read<TravelerPreferencesController>(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preferencesController =
        context.watch<TravelerPreferencesController>();
    // watch (sin usar la variable directamente) deja la sección atenta
    // a nuevas reservas: cada compra recalcula el historial del motor.
    context.watch<ReservationsStore>();
    // Atenta también a la sesión: al entrar se pide la lista remota y
    // al salir se vuelve al motor local.
    context.watch<AuthController>();

    // Recalcula cuando cambian las preferencias, la sesión o llega una
    // reserva nueva (todos ChangeNotifier; watch re-renderiza y aquí se
    // vuelve a evaluar con los datos frescos).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _rebuild();
    });

    if (!preferencesController.isActive) return const SizedBox.shrink();

    if (!preferencesController.hasPreferences) {
      return _EmptyState(
        onOpenPreferences: () => _openPreferencesSheet(context),
      );
    }

    final recommendations = _controller.recommendations;
    if (recommendations.isEmpty && !_controller.isLoading) {
      // PreferencesController dice que hay datos pero el motor aún está
      // recalculando en el primer frame: se muestra el header vacío.
      return const SizedBox.shrink();
    }

    // Impresiones de las tarjetas visibles del ranking. El tracker
    // deduplica por elemento y sesión los tipos `*_impression`, así
    // que un rebuild o un scroll no los inflan: si el tracker está
    // apagado (sin consentimiento) no pasa absolutamente nada.
    final tracker = context.read<UserEventTracker>();
    for (final entry in recommendations.asMap().entries) {
      tracker.track(
        'recommendation_impression',
        destinationId: _destinationId(entry.value),
        recommendationId: _listId(entry.value),
        position: entry.key,
        context: 'recommendations',
      );
    }

    // Con la lista del backend se aclara si es personalizada o el
    // respaldo de populares (estrategia `popular`/`fallback`).
    final strategy = _controller.strategy;
    final caption = strategy == 'popular' || strategy == 'fallback'
        ? 'Aún no tenemos suficiente señal de tu perfil: por ahora '
            'te mostramos los destinos más populares entre viajeros.'
        : 'Matching entre tus preferencias y nuestro catálogo: '
            'intereses (40%), presupuesto (25%), estacionalidad (20%) '
            'e historial (15%).';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.primaryDark,
                size: 19,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            const Expanded(
              child: Text(
                'Recomendado para ti',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          caption,
          style: const TextStyle(
            fontSize: 12,
            height: 1.4,
            color: AppColors.textTertiary,
          ),
        ),
        if (_controller.isLoading && recommendations.isEmpty) ...[
          // Cargando la lista del backend sin resultado local previo:
          // barra fina en vez de tarjetas vacías.
          const SizedBox(height: AppSpacing.lg),
          const LinearProgressIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surfaceVariant,
            minHeight: 2,
          ),
        ] else ...[
          const SizedBox(height: AppSpacing.lg),
          // Radar multi-destino (el gráfico que pidió el profesor):
          // perfil del usuario vs los 3 mejores matches, en colores.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadows.card,
            ),
            child: ComparisonRadar(results: recommendations),
          ),
          const SizedBox(height: AppSpacing.xl),
          for (final entry in recommendations.asMap().entries) ...[
            RecommendationCard(
              result: entry.value,
              onTap: () => _openMatchSheet(context, entry.value, entry.key),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onOpenPreferences});

  final VoidCallback onOpenPreferences;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppColors.goldGradient,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.primaryDark,
              size: 21,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Desbloquea tus recomendaciones',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Declara tus intereses, presupuesto y meses disponibles '
            'para que el motor compare tu perfil con cada destino y '
            'te muestre tu índice de afinidad.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          CustomButton(
            label: 'Declarar mis preferencias',
            icon: Icons.tune_rounded,
            onPressed: onOpenPreferences,
          ),
        ],
      ),
    );
  }
}
