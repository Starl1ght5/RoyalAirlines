import 'package:flutter_test/flutter_test.dart';
import 'package:royal_airlines/models/user_model.dart';

/// Pruebas de [UserModel]: serialización JSON y `copyWith`.
void main() {
  group('UserModel', () {
    test('fromJson construye un usuario a partir de la respuesta del backend',
        () {
      final user = UserModel.fromJson({
        'id': 'u1',
        'fullName': 'Ana Torres',
        'email': 'ana@royalairlines.com',
      });
      expect(user.id, 'u1');
      expect(user.fullName, 'Ana Torres');
      expect(user.email, 'ana@royalairlines.com');
      expect(user.avatarUrl, isNull);
    });

    test('fromJson conserva avatarUrl si el backend lo envía', () {
      final user = UserModel.fromJson({
        'id': 'u1',
        'fullName': 'Ana Torres',
        'email': 'ana@royalairlines.com',
        'avatarUrl': 'https://example.com/avatar.png',
      });
      expect(user.avatarUrl, 'https://example.com/avatar.png');
    });

    test('toJson serializa todos los campos', () {
      const user = UserModel(
        id: 'u1',
        fullName: 'Ana Torres',
        email: 'ana@royalairlines.com',
        avatarUrl: 'https://example.com/avatar.png',
      );
      final json = user.toJson();
      expect(json['id'], 'u1');
      expect(json['fullName'], 'Ana Torres');
      expect(json['email'], 'ana@royalairlines.com');
      expect(json['avatarUrl'], 'https://example.com/avatar.png');
    });

    test('copyWith reemplaza solo los campos indicados', () {
      const user = UserModel(
        id: 'u1',
        fullName: 'Ana Torres',
        email: 'ana@royalairlines.com',
      );
      final updated = user.copyWith(fullName: 'Ana María Torres');
      expect(updated.fullName, 'Ana María Torres');
      expect(updated.id, 'u1');
      expect(updated.email, 'ana@royalairlines.com');
    });
  });
}
