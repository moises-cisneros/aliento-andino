import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

/// Excepción lanzada cuando la calibración no puede completarse (muestras
/// insuficientes o atípicas) y debe reiniciarse.
class BreathCalibrationException implements Exception {
  final String message;
  const BreathCalibrationException(this.message);

  @override
  String toString() => 'BreathCalibrationException: $message';
}

/// [SUB-02-B] Algoritmo de ajuste dinámico del umbral de energía RMS.
///
/// A partir de las muestras de energía RMS capturadas durante la calibración
/// de "Soplo Suave" (HU-02), calcula el corte mínimo de activación del detector
/// acústico (YIN). El objetivo es que incluso los soplos tenues de un estudiante
/// con baja capacidad pulmonar superen el umbral, evitando penalizaciones
/// injustas por bajo volumen.
///
/// Usa la **media armónica** (robusta frente a picos altos) y el **percentil 25**
/// (extremo tenue estable) de las muestras, descartando valores atípicos de
/// ruido de impacto o silencio total.
class BreathCalibrator {
  /// Clave de persistencia local del umbral calibrado.
  static const String prefsKey = 'breath_rms_threshold';

  /// Clave de persistencia local de la fecha de última calibración.
  static const String lastCalibratedKey = 'breath_rms_last_calibrated';

  /// Muestras por encima de este valor se consideran ruido de impacto.
  static const double impactNoiseCeiling = 0.95;

  /// Muestras por debajo de este valor se consideran silencio total.
  static const double silenceFloor = 0.001;

  /// Mínimo de muestras válidas para una calibración confiable.
  static const int minValidSamples = 8;

  /// Umbral mínimo razonable para no desactivar el detector por completo.
  static const double absoluteFloor = 0.002;

  /// Margen por debajo del punto más tenue del soplo del usuario, de modo que
  /// los soplos suaves activen el detector con holgura.
  static const double marginFactor = 0.6;

  /// Instancia de preferencias inyectable (facilita las pruebas). Si es `null`,
  /// se resuelve `SharedPreferences.getInstance()` bajo demanda.
  final SharedPreferences? _prefs;

  const BreathCalibrator([this._prefs]);

  /// Descarta muestras atípicas (ruido de impacto o silencio total).
  List<double> _filterOutliers(List<double> samples) => samples
      .where((s) => s >= silenceFloor && s <= impactNoiseCeiling)
      .toList(growable: false);

  /// Media armónica: n / Σ(1/xᵢ). Penaliza fuertemente los valores pequeños,
  /// reflejando el nivel sostenible del soplo.
  double _harmonicMean(List<double> xs) {
    final inverseSum = xs.fold<double>(0.0, (acc, x) => acc + 1.0 / x);
    return xs.length / inverseSum;
  }

  /// Percentil [p] (0–100) por interpolación lineal sobre las muestras ordenadas.
  double _percentile(List<double> xs, double p) {
    final sorted = [...xs]..sort();
    if (sorted.length == 1) return sorted.first;
    final rank = (p / 100.0) * (sorted.length - 1);
    final low = rank.floor();
    final high = rank.ceil();
    if (low == high) return sorted[low];
    final frac = rank - low;
    return sorted[low] * (1 - frac) + sorted[high] * frac;
  }

  /// Calcula el umbral mínimo de activación a partir de las muestras RMS.
  ///
  /// Lanza [BreathCalibrationException] si, tras descartar atípicos, no hay
  /// suficientes muestras válidas.
  double calculateThreshold(List<double> rmsSamples) {
    final valid = _filterOutliers(rmsSamples);
    if (valid.length < minValidSamples) {
      throw const BreathCalibrationException(
        'Muestras insuficientes o atípicas; repite la calibración.',
      );
    }

    final harmonic = _harmonicMean(valid);
    final p25 = _percentile(valid, 25);

    // El corte se fija por debajo del punto más tenue estable del soplo, para
    // que los soplos suaves superen el umbral del detector con holgura.
    final threshold = math.min(harmonic, p25) * marginFactor;
    return threshold < absoluteFloor ? absoluteFloor : threshold;
  }

  Future<SharedPreferences> _resolvePrefs() async =>
      _prefs ?? await SharedPreferences.getInstance();

  /// Persiste el umbral calibrado localmente junto con la fecha.
  Future<void> saveThreshold(double threshold, [DateTime? timestamp]) async {
    final prefs = await _resolvePrefs();
    await prefs.setDouble(prefsKey, threshold);
    await prefs.setString(
      lastCalibratedKey,
      (timestamp ?? DateTime.now()).toIso8601String(),
    );
  }

  /// Carga el umbral calibrado previamente, o `null` si no existe.
  Future<double?> loadThreshold() async {
    final prefs = await _resolvePrefs();
    return prefs.getDouble(prefsKey);
  }

  /// Carga la fecha de la última calibración, o `null` si no existe.
  Future<DateTime?> loadLastCalibrated() async {
    final prefs = await _resolvePrefs();
    final raw = prefs.getString(lastCalibratedKey);
    return raw != null ? DateTime.tryParse(raw) : null;
  }
}
