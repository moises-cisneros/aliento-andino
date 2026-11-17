import 'dart:math' as math;
import 'dart:typed_data';

/// MVP de detección polifónica usando FFT + peak picking.
///
/// Pipeline:
///   PCM 16 → ventana Hann → FFT → magnitud → buscar N picos
///   → mapear cada pico a nota musical → si hay 3+ notas dentro de la misma
///   octava, intentar matchear con triadas mayor/menor conocidas.
///
/// Limitaciones del MVP:
/// - Solo detecta hasta 4 notas simultáneas.
/// - No detecta acordes con 7ma, 9na, suspendidos, inversiones complejas.
/// - Bajas frecuencias (<C3) tienen menos resolución.
/// - Falsos positivos con armónicos fuertes.
///
/// Para producción real, conviene migrar a un modelo ML (CREPE / Basic Pitch
/// de Spotify) compilado a TFLite. Esto es MVP "good enough" para piano simple.
class ChordDetector {
  static const int sampleRate = 44100;
  // Cuanto más grande, mejor resolución en bajos pero más latencia.
  static const int fftSize = 8192;

  // Notas musicales (A4 = 440Hz)
  static const List<String> _noteNames = [
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'A#',
    'B',
  ];

  /// Frecuencias mínima/máxima a considerar (piano: C2 a C6).
  static const double minFreq = 65.4; // C2
  static const double maxFreq = 1046.5; // C6
  static const double peakThreshold = 0.15; // umbral relativo al peak máximo

  /// Detecta hasta `maxNotes` notas en el buffer de audio.
  /// Retorna una lista ordenada por amplitud descendente.
  List<DetectedPitch> detectNotes(List<double> samples, {int maxNotes = 4}) {
    if (samples.length < fftSize) return const [];

    // Tomar últimos fftSize samples
    final buffer = samples.length > fftSize
        ? samples.sublist(samples.length - fftSize)
        : List<double>.from(samples);

    // Ventana de Hann para reducir spectral leakage
    final windowed = Float64List(fftSize);
    for (var i = 0; i < fftSize; i++) {
      final w = 0.5 * (1 - math.cos(2 * math.pi * i / (fftSize - 1)));
      windowed[i] = buffer[i] * w;
    }

    // FFT (Cooley-Tukey iterativo, requiere fftSize potencia de 2)
    final real = Float64List.fromList(windowed);
    final imag = Float64List(fftSize);
    _fft(real, imag);

    // Magnitud
    final binCount = fftSize ~/ 2;
    final magnitude = Float64List(binCount);
    for (var i = 0; i < binCount; i++) {
      magnitude[i] = math.sqrt(real[i] * real[i] + imag[i] * imag[i]);
    }

    // Picos en rango de piano
    final binWidth = sampleRate / fftSize;
    final minBin = (minFreq / binWidth).floor().clamp(1, binCount - 1);
    final maxBin = (maxFreq / binWidth).ceil().clamp(minBin + 1, binCount - 1);

    // Peak máximo en el rango
    double maxMag = 0;
    for (var i = minBin; i < maxBin; i++) {
      if (magnitude[i] > maxMag) maxMag = magnitude[i];
    }
    if (maxMag < 1e-6) return const [];

    final cutoff = maxMag * peakThreshold;

    // Encontrar picos locales (vecinos más bajos)
    final peaks = <DetectedPitch>[];
    for (var i = minBin + 1; i < maxBin - 1; i++) {
      final m = magnitude[i];
      if (m < cutoff) continue;
      if (m <= magnitude[i - 1] || m <= magnitude[i + 1]) continue;

      // Refinamiento parabolic (interpolación cuadrática)
      final alpha = magnitude[i - 1];
      final beta = m;
      final gamma = magnitude[i + 1];
      final p = 0.5 * (alpha - gamma) / (alpha - 2 * beta + gamma);
      final freq = (i + p) * binWidth;

      peaks.add(
        DetectedPitch(
          frequency: freq,
          magnitude: m,
          note: _frequencyToNote(freq),
          midi: _frequencyToMidi(freq),
        ),
      );
    }

    // Eliminar armónicos: si hay un pico a 2f, 3f, 4f... de otro, descartar
    final fundamentals = <DetectedPitch>[];
    peaks.sort((a, b) => b.magnitude.compareTo(a.magnitude));
    for (final p in peaks) {
      bool isHarmonic = false;
      for (final f in fundamentals) {
        if (f.frequency <= 0) continue;
        final ratio = p.frequency / f.frequency;
        final near = (ratio - ratio.round()).abs();
        if (ratio.round() >= 2 && near < 0.04) {
          isHarmonic = true;
          break;
        }
      }
      if (!isHarmonic) fundamentals.add(p);
      if (fundamentals.length >= maxNotes) break;
    }

    return fundamentals;
  }

  /// Dada una lista de notas, intenta identificar un acorde mayor/menor.
  ChordMatch? identifyChord(List<DetectedPitch> notes) {
    if (notes.length < 3) return null;

    // Reducir a clases de octava (0=C, 1=C#, ..., 11=B)
    final pitchClasses = notes.map((n) => n.midi % 12).toSet().toList()..sort();
    if (pitchClasses.length < 3) return null;

    // Probar cada nota como tónica
    for (final root in pitchClasses) {
      final intervals = pitchClasses.map((p) => (p - root + 12) % 12).toSet();
      // Mayor: 0-4-7
      if (intervals.containsAll({0, 4, 7})) {
        return ChordMatch(
          root: _noteNames[root],
          quality: 'major',
          label: '${_noteNames[root]} (Mayor)',
        );
      }
      // Menor: 0-3-7
      if (intervals.containsAll({0, 3, 7})) {
        return ChordMatch(
          root: _noteNames[root],
          quality: 'minor',
          label: '${_noteNames[root]}m (Menor)',
        );
      }
      // Disminuido: 0-3-6
      if (intervals.containsAll({0, 3, 6})) {
        return ChordMatch(
          root: _noteNames[root],
          quality: 'diminished',
          label: '${_noteNames[root]}° (Dim)',
        );
      }
      // Aumentado: 0-4-8
      if (intervals.containsAll({0, 4, 8})) {
        return ChordMatch(
          root: _noteNames[root],
          quality: 'augmented',
          label: '${_noteNames[root]}+ (Aum)',
        );
      }
    }
    return null;
  }

  // ============ Helpers ============

  String _frequencyToNote(double freq) {
    final midi = _frequencyToMidi(freq);
    final noteIdx = midi % 12;
    final octave = (midi / 12).floor() - 1;
    return '${_noteNames[noteIdx]}$octave';
  }

  int _frequencyToMidi(double freq) {
    return (69 + 12 * (math.log(freq / 440.0) / math.ln2)).round();
  }

  /// FFT iterativa Cooley-Tukey radix-2 in-place.
  void _fft(Float64List real, Float64List imag) {
    final n = real.length;
    // Bit-reversal permutation
    var j = 0;
    for (var i = 1; i < n; i++) {
      var bit = n >> 1;
      while (j & bit != 0) {
        j ^= bit;
        bit >>= 1;
      }
      j ^= bit;
      if (i < j) {
        final tr = real[i];
        real[i] = real[j];
        real[j] = tr;
        final ti = imag[i];
        imag[i] = imag[j];
        imag[j] = ti;
      }
    }
    // Butterflies
    for (var len = 2; len <= n; len <<= 1) {
      final ang = -2 * math.pi / len;
      final wlenReal = math.cos(ang);
      final wlenImag = math.sin(ang);
      for (var i = 0; i < n; i += len) {
        var wReal = 1.0;
        var wImag = 0.0;
        final half = len ~/ 2;
        for (var k = 0; k < half; k++) {
          final uReal = real[i + k];
          final uImag = imag[i + k];
          final vReal = real[i + k + half] * wReal - imag[i + k + half] * wImag;
          final vImag = real[i + k + half] * wImag + imag[i + k + half] * wReal;
          real[i + k] = uReal + vReal;
          imag[i + k] = uImag + vImag;
          real[i + k + half] = uReal - vReal;
          imag[i + k + half] = uImag - vImag;
          final nwReal = wReal * wlenReal - wImag * wlenImag;
          final nwImag = wReal * wlenImag + wImag * wlenReal;
          wReal = nwReal;
          wImag = nwImag;
        }
      }
    }
  }
}

class DetectedPitch {
  final double frequency;
  final double magnitude;
  final String note;
  final int midi;

  const DetectedPitch({
    required this.frequency,
    required this.magnitude,
    required this.note,
    required this.midi,
  });

  @override
  String toString() => '$note (${frequency.toStringAsFixed(1)}Hz)';
}

class ChordMatch {
  final String root;
  final String quality; // major/minor/diminished/augmented
  final String label;

  const ChordMatch({
    required this.root,
    required this.quality,
    required this.label,
  });
}
