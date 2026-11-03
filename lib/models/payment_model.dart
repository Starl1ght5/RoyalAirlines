/// PaymentModel
/// ------------
/// Representa el método de pago usado en una reserva, YA ENMASCARADO.
/// Deliberadamente NO incluye el número completo de tarjeta ni el CVV
/// — ni siquiera en este proyecto mock, para modelar la práctica
/// correcta: esos datos se envían una sola vez al procesador de pago
/// y nunca se persisten en el estado/modelo de la app.
class PaymentModel {
  final String cardHolderName;

  /// Solo los últimos 4 dígitos, ej. "•••• •••• •••• 4242".
  final String maskedCardNumber;

  final String expiry; // Formato "MM/YY"

  const PaymentModel({
    required this.cardHolderName,
    required this.maskedCardNumber,
    required this.expiry,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      cardHolderName: json['cardHolderName'] as String,
      maskedCardNumber: json['maskedCardNumber'] as String,
      expiry: json['expiry'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cardHolderName': cardHolderName,
      'maskedCardNumber': maskedCardNumber,
      'expiry': expiry,
    };
  }
}
