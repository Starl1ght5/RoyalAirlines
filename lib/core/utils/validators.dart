/// Validators
/// ----------
/// Funciones de validación de formularios centralizadas y reutilizables.
/// Se usan como `validator:` en TextFormField desde Login, Register y
/// cualquier módulo futuro que necesite los mismos criterios, evitando
/// reescribir la misma expresión regular en múltiples archivos.
class Validators {
  Validators._();

  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9.a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  /// Valida formato de correo electrónico.
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Ingresa tu correo electrónico';
    }
    if (!_emailRegex.hasMatch(value.trim())) {
      return 'Ingresa un correo electrónico válido';
    }
    return null;
  }

  /// Valida contraseña con longitud mínima (criterio simple para el
  /// alcance de este proyecto; en un backend real se validaría también
  /// del lado del servidor).
  static String? password(String? value, {int minLength = 6}) {
    if (value == null || value.isEmpty) {
      return 'Ingresa tu contraseña';
    }
    if (value.length < minLength) {
      return 'La contraseña debe tener al menos $minLength caracteres';
    }
    return null;
  }

  /// Valida que un campo de texto simple no esté vacío (nombre, apellido, etc.).
  /// Se agrega desde ya porque Register (Módulo 3) lo va a necesitar.
  static String? required(String? value, {String fieldName = 'Este campo'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName es obligatorio';
    }
    return null;
  }
}
