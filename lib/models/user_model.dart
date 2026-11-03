/// UserModel
/// ---------
/// Representa un usuario autenticado de Royal Airlines.
///
/// Vive en `models/` (no dentro de `features/auth/`) porque no es
/// exclusivo del login: Profile, Booking (datos del pasajero que reserva)
/// y Reservations también lo van a consumir. Mantenerlo aquí evita que
/// cada feature defina su propia versión del usuario (DRY).
class UserModel {
  final String id;
  final String fullName;
  final String email;
  final String? avatarUrl;

  const UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    this.avatarUrl,
  });

  /// Deserializa desde JSON (respuesta de API/mock).
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      email: json['email'] as String,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }

  /// Serializa a JSON (por ejemplo, para persistir sesión localmente).
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'avatarUrl': avatarUrl,
    };
  }

  /// Crea una copia con campos reemplazados (útil al editar perfil).
  UserModel copyWith({
    String? id,
    String? fullName,
    String? email,
    String? avatarUrl,
  }) {
    return UserModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}
