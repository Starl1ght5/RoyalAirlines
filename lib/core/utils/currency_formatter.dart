/// CurrencyFormatter
/// -----------------
/// Formateador único de moneda para toda la app (pesos colombianos).
/// Centralizado aquí para que Flights, Booking y cualquier módulo
/// futuro (Reservations, Profile) muestren el mismo formato exacto,
/// sin repetir la lógica de separadores de miles en cada widget.
class CurrencyFormatter {
  CurrencyFormatter._();

  /// Formatea un valor numérico como pesos colombianos: 414000 -> "COP 414.000".
  static String cop(num value) => 'COP ${_group(value.round())}';

  /// Formatea un valor numérico como DÓLARES: 414 -> "USD 414".
  ///
  /// La única ruta en USD de toda la app es el histórico de precios
  /// (`GET /prices/history`), que siempre muestra la etiqueta `USD`
  /// explícita: aquí NO se convierte a COP porque no hay una tasa
  /// oficial que la app pueda afirmar.
  static String usd(num value) => 'USD ${_group(value.round())}';

  /// Versión corta para ejes de gráfica: 414 -> "414", 1450 -> "1.450".
  static String usdShort(num value) => _group(value.round());

  /// Agrupa el entero en bloques de 3 con punto (414000 -> "414.000").
  static String _group(int value) {
    final digits = value.abs().toString();
    final buffer = StringBuffer();
    if (value < 0) buffer.write('-');
    for (var i = 0; i < digits.length; i++) {
      final remaining = digits.length - i;
      if (i != 0 && remaining % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}
