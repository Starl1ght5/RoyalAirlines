/// AppRoutes
/// ---------
/// Fuente única de verdad para los nombres de ruta de la aplicación.
///
/// En lugar de escribir strings como '/login' repetidos en múltiples
/// archivos (main.dart, login_screen.dart, etc.),
/// todos los módulos referencian estas constantes. Esto evita errores
/// de tipeo y centraliza el mapa de navegación en un solo lugar.
class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String register = '/register';

  /// Contenedor de navegación principal (Módulo 4): Inicio, Mis Reservas, Perfil.
  static const String main = '/main';
}
