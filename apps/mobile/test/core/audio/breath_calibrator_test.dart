import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/audio/breath_calibrator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BreathCalibrator.calculateThreshold', () {
    const calibrator = BreathCalibrator();

    test('umbral de un soplo suave estable queda por debajo del nivel real', () {
      final samples = List<double>.filled(20, 0.10);
      final threshold = calibrator.calculateThreshold(samples);

      // marginFactor = 0.6 → 0.10 * 0.6 = 0.06
      expect(threshold, closeTo(0.06, 1e-9));
      // Debe ser menor que el nivel del soplo para que los soplos suaves activen.
      expect(threshold, lessThan(0.10));
    });

    test('descarta ruido de impacto y silencio sin inflar el umbral', () {
      final samples = <double>[
        ...List<double>.filled(16, 0.10),
        0.99, // ruido de impacto → descartado
        0.0005, // silencio total → descartado
      ];
      final threshold = calibrator.calculateThreshold(samples);

      // Los atípicos no deben desplazar el umbral calculado con las 16 válidas.
      expect(threshold, closeTo(0.06, 1e-9));
    });

    test('respeta el umbral mínimo absoluto', () {
      final samples = List<double>.filled(12, 0.002);
      final threshold = calibrator.calculateThreshold(samples);

      // 0.002 * 0.6 = 0.0012 < absoluteFloor (0.002) → se eleva al piso.
      expect(threshold, BreathCalibrator.absoluteFloor);
    });

    test('lanza excepción con muestras válidas insuficientes', () {
      final samples = <double>[0.10, 0.11, 0.09]; // 3 < minValidSamples (8)
      expect(
        () => calibrator.calculateThreshold(samples),
        throwsA(isA<BreathCalibrationException>()),
      );
    });

    test('la media armónica sigue el extremo tenue del soplo', () {
      // Soplo con un pico alto puntual: la media armónica no se infla por él.
      final samples = <double>[
        ...List<double>.filled(10, 0.08),
        ...List<double>.filled(10, 0.40),
      ];
      final threshold = calibrator.calculateThreshold(samples);

      // Dominado por el extremo tenue (≈0.08), no por el promedio aritmético.
      expect(threshold, lessThan(0.08));
    });
  });

  group('BreathCalibrator.saveThreshold / loadThreshold', () {
    test('persiste y recupera el umbral vía SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final calibrator = BreathCalibrator(prefs);

      await calibrator.saveThreshold(0.042);

      expect(prefs.getDouble(BreathCalibrator.prefsKey), 0.042);
      expect(await calibrator.loadThreshold(), 0.042);
    });

    test('loadThreshold retorna null si no hay valor previo', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final calibrator = BreathCalibrator(prefs);

      expect(await calibrator.loadThreshold(), isNull);
    });
  });
}
