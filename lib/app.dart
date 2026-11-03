import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:royal_airlines/core/navigation/app_keys.dart';
import 'package:royal_airlines/core/routes/app_pages.dart';
import 'package:royal_airlines/core/theme/app_colors.dart';
import 'package:royal_airlines/core/theme/app_theme.dart';
import 'package:royal_airlines/features/auth/controller/auth_controller.dart';
import 'package:royal_airlines/features/auth/screens/login_screen.dart';
import 'package:royal_airlines/features/favorites/controller/favorites_controller.dart';
import 'package:royal_airlines/features/reservations/repository/reservations_store.dart';
import 'package:royal_airlines/navigation/main_navigation.dart';
import 'package:royal_airlines/services/push_message_handler.dart';
import 'package:royal_airlines/services/push_notification_service.dart';
import 'package:royal_airlines/services/tracking_consent_service.dart';
import 'package:royal_airlines/services/user_event_tracker.dart';

/// RoyalAirlinesApp
/// ----------------
/// Widget raíz de la aplicación. Mantiene el estado global real de la
/// app en la capa funcional actual: [AuthController] para sesión y
/// [ReservationsStore] para historial de reservas.
///
/// El estado global usa los controllers y stores activos de cada modulo.
/// No se registran fuentes de estado duplicadas para mantener una sola
/// fuente de verdad durante la integracion con backend.
class RoyalAirlinesApp extends StatelessWidget {
  const RoyalAirlinesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => ReservationsStore()),
        // Favoritos globales: los corazones de Home, resultados y
        // recomendaciones comparten UN solo estado (cargado al abrir
        // sesión, ver _syncFavorites en _AuthGate).
        ChangeNotifierProvider(create: (_) => FavoritesController()),
        // UserEventTracker NO es ChangeNotifier, por eso va con
        // Provider (no ChangeNotifierProvider). `lazy: false` para que
        // su timer de flush corra aunque todavía nadie escuche; el
        // dispose cancela el timer al desmontar la app.
        Provider<UserEventTracker>(
          create: (_) => UserEventTracker(),
          dispose: (_, tracker) => tracker.dispose(),
          lazy: false,
        ),
      ],
      child: MaterialApp(
        title: 'Royal Airlines',
        // Para navegar y avisar desde una notificación push, fuera del árbol.
        navigatorKey: appNavigatorKey,
        scaffoldMessengerKey: appMessengerKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const _AuthGate(),
        routes: AppPages.routes,
      ),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

/// Restaura la sesión, mantiene la puerta de consentimiento de
/// tracking, sincroniza los favoritos (`GET /favorites`) y vuelca el
/// buffer de eventos cuando la app va a segundo plano (ver
/// [didChangeAppLifecycleState]).
class _AuthGateState extends State<_AuthGate> with WidgetsBindingObserver {
  final TrackingConsentService _consent = TrackingConsentService();

  /// Referencia guardada en [initState]: en [dispose] ya NO se puede
  /// hacer `context.read` (el elemento está desactivado y el lookup
  /// lanza "Looking up a deactivated widget's ancestor is unsafe").
  late final AuthController _auth;

  /// `true` cuando el consentimiento de la sesión actual ya se leyó
  /// del backend. Evita que cada notifyListeners de AuthController
  /// (login cargando, recordarme, etc.) dispare un `GET` nuevo.
  bool _consentSynced = false;

  /// Mismo criterio que [_consentSynced], pero para el `GET /favorites`
  /// de la sesión actual.
  bool _favoritesSynced = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // tryRestoreSession notifica al terminar: por ahí entra la primera
    // sincronización; los logins posteriores también pasan por aquí.
    _auth = context.read<AuthController>();
    _auth.addListener(_syncTrackingConsent);
    _auth.addListener(_syncFavorites);
    _auth.addListener(_syncPushSession);
    // El handler registra `offer_click` con el mismo tracker de toda la app.
    PushMessageHandler.instance.tracker = context.read<UserEventTracker>();
    _auth.tryRestoreSession();
  }

  @override
  void dispose() {
    _auth.removeListener(_syncTrackingConsent);
    _auth.removeListener(_syncFavorites);
    _auth.removeListener(_syncPushSession);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.paused) return;
    // Último lote antes de que el sistema operativo pause/mate la
    // app: sin esto se pierden los eventos acumulados desde el último
    // flush automático (el tracker hace flush cada 15 s o a los 20
    // eventos, pero nada garantiza que el timer llegue a correr).
    context.read<UserEventTracker>().flush();
  }

  /// Puerta de consentimiento: `GET /users/me/consent` ->
  /// `tracker.enabled`. Sin sesión no hay JWT (los eventos darían 401)
  /// y sin `tracking=true` el backend no guardaría nada, así que el
  /// tracker arranca apagado y solo se enciende con confirmación.
  void _syncTrackingConsent() {
    final tracker = context.read<UserEventTracker>();

    if (!_auth.isAuthenticated) {
      _consentSynced = false;
      tracker.enabled = false;
      return;
    }
    if (_consentSynced) return;
    _consentSynced = true;
    _applyRemoteConsent(tracker);
  }

  Future<void> _applyRemoteConsent(UserEventTracker tracker) async {
    try {
      // Un solo GET para los dos permisos: tracking y alertas de ofertas.
      final consent = await _consent.fetch();
      tracker.enabled = consent.tracking;
      // Alertas activadas en el backend: se registra este dispositivo SIN pedir
      // permiso (el diálogo del sistema se pide al guardar preferencias o al
      // activar el interruptor de Perfil). Nunca lanza.
      if (consent.marketingOptIn) {
        PushNotificationService.instance.registerIfPermitted();
      }
    } catch (_) {
      // Sin red o con el endpoint caído NO se asume `false` como
      // verdad: se deja el tracker apagado (comportamiento prudente)
      // y se vuelve a intentar en el próximo cambio de estado de auth.
      // El usuario también puede activarlo desde Perfil.
      _consentSynced = false;
    }
  }

  /// Avisa al handler de push del estado de la sesión: con sesión abre la oferta
  /// que haya quedado pendiente (app abierta desde una notificación); sin sesión
  /// y ya restaurada, descarta lo pendiente.
  void _syncPushSession() {
    PushMessageHandler.instance.onSession(
      authenticated: _auth.isAuthenticated,
      restoring: _auth.isRestoringSession,
    );
  }

  /// Carga `GET /favorites` al arrancar la sesión y limpia la lista
  /// al cerrarla, para que ningún corazón arranque con datos de la
  /// cuenta anterior. Si el `GET` falla (sin red) se reintenta en el
  /// próximo notify de AuthController en vez de dejar la lista vacía
  /// como si el usuario no tuviera favoritos.
  void _syncFavorites() {
    final favorites = context.read<FavoritesController>();

    if (!_auth.isAuthenticated) {
      _favoritesSynced = false;
      favorites.clear();
      return;
    }
    if (_favoritesSynced && favorites.status != FavoritesStatus.error) return;
    _favoritesSynced = true;
    favorites.load();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, authController, _) {
        if (authController.isRestoringSession) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2.4,
              ),
            ),
          );
        }

        return authController.isAuthenticated
            ? const MainNavigation()
            : const LoginScreen();
      },
    );
  }
}
