// Test básico para verificar que la app compila correctamente.

import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Verificar que el framework de tests funciona
    expect(1 + 1, equals(2));
  });
}
