import 'package:flutter/foundation.dart';
import 'package:royal_airlines/core/network/jwt_claims.dart';
import 'package:royal_airlines/models/user_model.dart';
import 'package:royal_airlines/services/push_notification_service.dart';
import 'package:royal_airlines/services/auth_service.dart';
import 'package:royal_airlines/services/session_storage.dart';

/// AuthStatus
/// ----------
enum AuthStatus { idle, loading, success, error }

/// ProfileUpdateStatus
/// -------------------
enum ProfileUpdateStatus { idle, loading, success, error }

/// AuthController
/// --------------
/// Gestor de estado de autenticación y perfil. Ahora persiste la
/// sesión en disco vía [SessionStorage]: al iniciar sesión, registrar
/// una cuenta o editar el perfil, guarda el usuario localmente para
/// que [tryRestoreSession] pueda recuperarlo automáticamente la
/// próxima vez que se abra la app — sin pedir credenciales de nuevo,
/// igual que apps como Instagram o Steam. La sesión solo se borra al
/// llamar [logout] explícitamente.
class AuthController extends ChangeNotifier {
  AuthController({AuthService? authService, SessionStorage? sessionStorage})
      : _authService = authService ?? AuthService(),
        _sessionStorage = sessionStorage ?? SessionStorage();

  final AuthService _authService;
  final SessionStorage _sessionStorage;

  AuthStatus _status = AuthStatus.idle;
  String? _errorMessage;
  bool _rememberMe = false;
  UserModel? _currentUser;
  bool _isGuest = false;

  AuthStatus _registerStatus = AuthStatus.idle;
  String? _registerErrorMessage;

  ProfileUpdateStatus _profileStatus = ProfileUpdateStatus.idle;
  String? _profileErrorMessage;

  /// Estado del login social (Google/Apple). Usa flag propios para no
  /// pisar el banner de error del login con correo ni el del registro:
  /// el error social se muestra junto a los botones sociales.
  bool _isSocialLoading = false;
  String? _socialErrorMessage;

  /// `true` mientras se está comprobando si hay una sesión guardada al
  /// arrancar la app. Evita parpadeos de UI que
  /// asuman "no autenticado" antes de terminar de leer el storage.
  bool _isRestoringSession = true;

  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get rememberMe => _rememberMe;
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _status == AuthStatus.loading;
  bool get isAuthenticated =>
      _status == AuthStatus.success && _currentUser != null;
  bool get isGuest => _isGuest;
  bool get isRestoringSession => _isRestoringSession;

  AuthStatus get registerStatus => _registerStatus;
  String? get registerErrorMessage => _registerErrorMessage;
  bool get isRegisterLoading => _registerStatus == AuthStatus.loading;

  ProfileUpdateStatus get profileStatus => _profileStatus;
  String? get profileErrorMessage => _profileErrorMessage;
  bool get isProfileLoading => _profileStatus == ProfileUpdateStatus.loading;

  bool get isSocialLoading => _isSocialLoading;
  String? get socialErrorMessage => _socialErrorMessage;

  void toggleRememberMe(bool value) {
    _rememberMe = value;
    notifyListeners();
  }

  void continueAsGuest() {
    _isGuest = true;
    notifyListeners();
  }

  /// Intenta recuperar una sesión guardada en el dispositivo. Se llama
  /// UNA vez al arrancar la app, antes de mostrar la pantalla inicial.
  /// Si hay un usuario guardado, la app entra directo sin pedir login;
  /// si no, el flujo normal (Login) continúa igual.
  ///
  /// Se intenta refrescar el perfil contra el backend
  /// (`GET /users/me`) con el token guardado, pero la vigencia de la
  /// sesión NO se decide solo por ese código HTTP:
  /// - Si el token guardado está VENCIDO (su claim `exp` ya pasó), se
  ///   borra la sesión y se pide login de nuevo.
  /// - Si el backend no responde (caído o sin internet), o responde 401
  ///   con un token aún vigente, se conserva la sesión guardada para no
  ///   dejar al usuario fuera de la app por un detalle del servidor; los
  ///   endpoints protegidos mostrarán su propio error al conectarse.
  Future<void> tryRestoreSession() async {
    // Todo el proceso va en try/finally: si loadUser o el parseo del
    // perfil fallan con algo inesperado (no AuthException), la app DEBE
    // terminar el arranque — dejar _isRestoringSession en true sería
    // un spinner infinito en el AuthGate.
    try {
      final savedUser = await _sessionStorage.loadUser();
      if (savedUser != null) {
        try {
          final fresh = await _authService.getProfile();
          // Las cuentas antiguas pueden no tener nombre guardado en el
          // backend: se conserva el del dispositivo en vez de borrarlo
          // con una cadena vacía.
          _currentUser = fresh.fullName.trim().isEmpty
              ? fresh.copyWith(fullName: savedUser.fullName)
              : fresh;
          _status = AuthStatus.success;
          _isGuest = false;
        } on AuthException catch (e) {
          final token = await _sessionStorage.loadToken();
          final expired = JwtClaims.tryParse(token)?.isExpired ?? true;

          if (e.statusCode == 401 && expired) {
            // Token vencido de verdad: hay que pedir login otra vez.
            await _sessionStorage.clear();
          } else {
            // El backend no responde, o rechazó el token por un motivo
            // distinto a la expiración. Si el token sigue vigente, la
            // sesión se conserva: echarla sería dejar al usuario fuera
            // por un detalle del servidor.
            _currentUser = savedUser;
            _status = AuthStatus.success;
            _isGuest = false;
          }
        }
      }
    } catch (_) {
      // Algo inesperó al leer storage o parsear el perfil: se arranca
      // como sesión nueva en vez de quedarse cargando para siempre.
      _currentUser = null;
      _status = AuthStatus.idle;
    } finally {
      _isRestoringSession = false;
      notifyListeners();
    }
  }

  Future<void> login({required String email, required String password}) async {
    // Un solo flujo de autenticación a la vez: si el login social está
    // en curso, el de correo no arranca (y viceversa vía los guards de
    // _loginWithSocialProvider), para que dos flujos no se peleen por
    // _currentUser/_status.
    if (_isSocialLoading) return;
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.login(email: email, password: password);
      _currentUser = user;
      _status = AuthStatus.success;
      _errorMessage = null;
      _isGuest = false;
      await _saveUserQuietly(user);
    } on AuthException catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.message;
    } catch (_) {
      _status = AuthStatus.error;
      _errorMessage = 'Ocurrió un error inesperado. Intenta de nuevo.';
    }
    notifyListeners();
  }

  /// Persiste el usuario en almacenamiento local. Si eso falla (p. ej.
  /// preferencias llenas o storage corrupto), el login NO se marca como
  /// fallido: la sesión en el backend ya existe y echar al usuario por
  /// un detalle local sería peor que no recordarlo la próxima vez.
  Future<void> _saveUserQuietly(UserModel user) async {
    try {
      await _sessionStorage.saveUser(user);
    } catch (_) {
      // Se ignora a propósito (ver doc).
    }
  }

  void resetStatus() {
    _status = AuthStatus.idle;
    _errorMessage = null;
    notifyListeners();
  }

  /// Login con Google. Al exito guarda la sesión igual que [login]; si
  /// el usuario cancela el diálogo de Google (devuelve `null`), no pasa
  /// nada y la UI queda como estaba.
  Future<void> loginWithGoogle() => _loginWithSocialProvider(
        () => _authService.signInWithGoogle(),
      );

  /// Login con Apple. Mismo contrato que [loginWithGoogle].
  Future<void> loginWithApple() => _loginWithSocialProvider(
        () => _authService.signInWithApple(),
      );

  Future<void> _loginWithSocialProvider(
    Future<UserModel?> Function() signIn,
  ) async {
    // Exclusión mutua con el resto de flujos de autenticación: nunca
    // dos peticiones de sesión en paralelo escribiendo el mismo estado.
    if (_isSocialLoading ||
        _status == AuthStatus.loading ||
        _registerStatus == AuthStatus.loading) {
      return;
    }
    _isSocialLoading = true;
    _socialErrorMessage = null;
    notifyListeners();

    try {
      final user = await signIn();
      if (user == null) return; // el usuario canceló el diálogo
      _currentUser = user;
      _status = AuthStatus.success;
      _errorMessage = null;
      _isGuest = false;
      await _saveUserQuietly(user);
    } on AuthException catch (e) {
      // No se toca _status: el banner de login/registro haría
      // `errorMessage!` y el error social se muestra junto a los
      // botones, no en ese banner.
      _socialErrorMessage = e.message;
    } catch (_) {
      _socialErrorMessage = 'Ocurrió un error inesperado. Intenta de nuevo.';
    } finally {
      _isSocialLoading = false;
      notifyListeners();
    }
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    if (_isSocialLoading) return;
    _registerStatus = AuthStatus.loading;
    _registerErrorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.register(
          fullName: fullName, email: email, password: password);
      _currentUser = user;
      _registerStatus = AuthStatus.success;
      _registerErrorMessage = null;
      _status = AuthStatus.success;
      _errorMessage = null;
      _isGuest = false;
      await _saveUserQuietly(user);
    } on AuthException catch (e) {
      _registerStatus = AuthStatus.error;
      _registerErrorMessage = e.message;
    } catch (_) {
      _registerStatus = AuthStatus.error;
      _registerErrorMessage = 'Ocurrió un error inesperado. Intenta de nuevo.';
    }
    notifyListeners();
  }

  void resetRegisterStatus() {
    _registerStatus = AuthStatus.idle;
    _registerErrorMessage = null;
    notifyListeners();
  }

  Future<void> updateProfile(
      {required String fullName, required String email}) async {
    final user = _currentUser;
    if (user == null) return;

    _profileStatus = ProfileUpdateStatus.loading;
    _profileErrorMessage = null;
    notifyListeners();

    try {
      final updated = await _authService.updateProfile(
        fullName: fullName,
        email: email,
      );
      _currentUser = updated;
      _profileStatus = ProfileUpdateStatus.success;
      // Actualiza también la sesión guardada, para que el nombre/correo
      // nuevo persista tras cerrar y reabrir la app.
      await _sessionStorage.saveUser(updated);
    } on AuthException catch (e) {
      _profileStatus = ProfileUpdateStatus.error;
      _profileErrorMessage = e.message;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _currentUser;
    if (user == null) return;

    _profileStatus = ProfileUpdateStatus.loading;
    _profileErrorMessage = null;
    notifyListeners();

    try {
      await _authService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      _profileStatus = ProfileUpdateStatus.success;
    } on AuthException catch (e) {
      _profileStatus = ProfileUpdateStatus.error;
      _profileErrorMessage = e.message;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  void resetProfileStatus() {
    _profileStatus = ProfileUpdateStatus.idle;
    _profileErrorMessage = null;
    notifyListeners();
  }

  Future<void> requestPasswordReset({required String email}) async {
    await _authService.requestPasswordReset(email: email);
  }

  /// Restablece la contraseña con el código de recuperación.
  ///
  /// Se usa sin sesión iniciada, así que no toca [currentUser]: solo
  /// expone el estado de la operación para la pantalla que lo consuma.
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    _profileStatus = ProfileUpdateStatus.loading;
    _profileErrorMessage = null;
    notifyListeners();

    try {
      await _authService.resetPassword(
        email: email,
        code: code,
        newPassword: newPassword,
      );
      _profileStatus = ProfileUpdateStatus.success;
    } on AuthException catch (e) {
      _profileStatus = ProfileUpdateStatus.error;
      _profileErrorMessage = e.message;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  /// Cierra sesión: borra tanto el estado en memoria como la sesión
  /// guardada en disco. Es la ÚNICA forma en que la app vuelve a pedir
  /// login — nunca por cerrar/reabrir la app.
  Future<void> logout() async {
    // ANTES de borrar la sesión: dar de baja el dispositivo necesita el JWT.
    // Con tope de 3 s para que cerrar sesión sin red no se quede colgado; si
    // no alcanza, el próximo usuario que inicie sesión en este teléfono se
    // queda con el token (el PUT lo reasigna).
    try {
      await PushNotificationService.instance
          .unregister()
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // Un fallo de push nunca debe impedir cerrar sesión.
    }
    await _authService.logout();
    await _sessionStorage.clear();
    _currentUser = null;
    _status = AuthStatus.idle;
    _errorMessage = null;
    _isGuest = false;
    // Limpia también errores de flujos anteriores: al volver a la
    // pantalla de Login no debe reaparecer un error social o de
    // registro viejo.
    _socialErrorMessage = null;
    _registerStatus = AuthStatus.idle;
    _registerErrorMessage = null;
    _profileStatus = ProfileUpdateStatus.idle;
    _profileErrorMessage = null;
    notifyListeners();
  }
}
