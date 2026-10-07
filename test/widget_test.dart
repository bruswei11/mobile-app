import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_app/main.dart';
import 'package:mobile_app/services/preferencias.dart';

void main() {
  testWidgets('La app arranca y muestra la pantalla de login', (WidgetTester tester) async {
    await tester.pumpWidget(SistemaPsicologiaApp(preferencias: Preferencias()));
    await tester.pump();

    expect(find.text('Ingresar'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });
}
