import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:royal_airlines/app.dart';

void main() {
  testWidgets('Royal Airlines inicia correctamente',
      (WidgetTester tester) async {
    // Carga la aplicación
    await tester.pumpWidget(
      const RoyalAirlinesApp(),
    );

    // Verifica que el árbol principal de la aplicación se haya montado.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
