/// PassengerModel
/// --------------
/// Datos de un pasajero capturados en el formulario de Booking. Vive
/// en `models/` porque Reservations (mostrar detalle de una reserva
/// pasada) y Profile también necesitarán esta misma estructura.
class PassengerModel {
  final String fullName;
  final String documentNumber;
  final DateTime birthDate;

  const PassengerModel({
    required this.fullName,
    required this.documentNumber,
    required this.birthDate,
  });

  factory PassengerModel.fromJson(Map<String, dynamic> json) {
    return PassengerModel(
      fullName: json['fullName'] as String,
      documentNumber: json['documentNumber'] as String,
      birthDate: DateTime.parse(json['birthDate'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fullName': fullName,
      'documentNumber': documentNumber,
      'birthDate': birthDate.toIso8601String(),
    };
  }
}
