import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:royal_airlines/core/theme/app_colors.dart';
import 'package:royal_airlines/features/auth/controller/auth_controller.dart';
import 'package:royal_airlines/features/home/screens/home_screen.dart';
import 'package:royal_airlines/features/profile/screens/profile_screen.dart';
import 'package:royal_airlines/features/reservations/repository/reservations_store.dart';
import 'package:royal_airlines/features/traveler_profile/screens/traveler_profile_screen.dart';
import 'package:royal_airlines/shared/widgets/custom_navigation_bar.dart';

/// MainNavigation
/// --------------
/// Contenedor de navegación principal: Inicio, Para ti y Perfil.
/// Usa un [PageView] para cambiar de tab deslizando el dedo
/// horizontalmente (la pantalla sigue el gesto con su animación
/// natural) o tocando la barra inferior (con la misma transición).
/// Cada tab va envuelto en [_KeepAlivePage] para que conserve su
/// estado al cambiar.
///
/// "Mis Reservas" ([ReservationsScreen]) NO vive en este navbar: es un
/// dato 100% personal del usuario (sus propias reservas), así que se
/// accede desde dentro de [ProfileScreen] para no saturar la barra
/// principal con demasiadas opciones.
///
/// También es el ÚNICO punto que sincroniza [ReservationsStore] con la
/// sesión activa: al autenticarse carga el historial desde el backend, y
/// al cerrar sesión limpia el estado en memoria. Vive montado tanto
/// tras el login normal como tras "Explorar sin cuenta" (que remueve el
/// AuthGate del árbol), por eso la sincronización no puede quedar solo
/// en [RoyalAirlinesApp].
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  bool _initialIndexApplied = false;

  PageController? _pageController;

  AuthController? _auth;
  String? _syncedUserId;

  static const List<NavItem> _navItems = [
    NavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Inicio',
    ),
    NavItem(
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore_rounded,
      label: 'Para ti',
    ),
    NavItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Perfil',
    ),
  ];

  static final List<Widget> _tabs = [
    const _KeepAlivePage(child: HomeScreen()),
    const _KeepAlivePage(child: TravelerProfileScreen()),
    const _KeepAlivePage(child: ProfileScreen()),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialIndexApplied) {
      _initialIndexApplied = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is int && args >= 0 && args < _tabs.length) {
        _currentIndex = args;
      }
      // El PageController se crea aquí (y no en initState) para poder
      // leer los arguments de la ruta y arrancar directamente en el
      // tab que corresponda.
      _pageController = PageController(initialPage: _currentIndex);
    }

    // Suscripción perezosa al AuthController: funciona tanto si esta
    // pantalla se montó tras un login normal como si el usuario era
    // invitado y acabó de iniciar sesión desde aquí.
    final auth = context.read<AuthController>();
    if (!identical(_auth, auth)) {
      _auth?.removeListener(_syncReservationsWithSession);
      _auth = auth;
      _auth!.addListener(_syncReservationsWithSession);
      _syncReservationsWithSession();
    }
  }

  @override
  void dispose() {
    _auth?.removeListener(_syncReservationsWithSession);
    _pageController?.dispose();
    super.dispose();
  }

  void _syncReservationsWithSession() {
    final store = context.read<ReservationsStore>();
    final user = _auth?.currentUser;

    if (_auth == null || !_auth!.isAuthenticated || user == null) {
      if (_syncedUserId != null) {
        _syncedUserId = null;
        store.clear();
      }
      return;
    }

    if (_syncedUserId == user.id) return;
    _syncedUserId = user.id;
    // Backend primero, disco como fallback (ver ReservationsStore).
    store.loadForUser(user.id);
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    // Misma duración/curva que el indicador animado de la barra
    // inferior, para que ambas animaciones se sientan sincronizadas.
    _pageController?.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _onPageChanged(int index) {
    HapticFeedback.lightImpact();
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: _tabs,
      ),
      bottomNavigationBar: CustomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        items: _navItems,
      ),
    );
  }
}

/// _KeepAlivePage
/// --------------
/// Mantiene vivo cada tab dentro del [PageView]. Sin esto, al deslizar
/// a otra pestaña la anterior se destruiría y perdería su estado
/// (búsquedas del Home, posiciones de scroll, datos cargados, etc.).
class _KeepAlivePage extends StatefulWidget {
  final Widget child;

  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
