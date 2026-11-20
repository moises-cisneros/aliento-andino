/// Instrumentos de viento andino soportados en Aliento Andino.
enum InstrumentType { quena, zampona, tarka }

/// Extension on [InstrumentType] providing labels and domain metadata.
extension InstrumentTypeExtension on InstrumentType {
  String get displayName {
    switch (this) {
      case InstrumentType.quena:
        return 'Quena';
      case InstrumentType.zampona:
        return 'Zampoña';
      case InstrumentType.tarka:
        return 'Tarka';
    }
  }

  double get defaultToleranceCents {
    switch (this) {
      case InstrumentType.quena:
        return 15.0;
      case InstrumentType.zampona:
        return 20.0;
      case InstrumentType.tarka:
        return 25.0;
    }
  }
}

/// Instrumentos/timbres disponibles para el sintetizador ([ToneSynth]) y el dominio andino.
///
/// Solo los instrumentos andinos canónicos: Quena, Zampoña y Tarka.
typedef Instrument = InstrumentType;

/// Perfil sonoro de un aerófono andino.
class InstrumentVoice {
  /// Pesos de los armónicos (índice 0 = fundamental, 1 = 2º armónico, …).
  final List<double> harmonics;

  /// Constante de caída suave durante el sostenido (aerófonos sostienen el aire).
  final double decay;

  /// Ganancia maestra (0..1).
  final double gain;

  /// Tiempo de ataque de soplo en segundos (evita el golpe percusivo de piano).
  final double attackSeconds;

  /// Nivel de aire / soplo característico del aerófono (0..1).
  final double breathNoise;

  /// Profundidad de vibrato natural de columna de aire (en fracción de frecuencia).
  final double vibratoDepth;

  /// Frecuencia de vibrato (Hz).
  final double vibratoHz;

  const InstrumentVoice(
    this.harmonics,
    this.decay,
    this.gain, {
    this.attackSeconds = 0.045,
    this.breathNoise = 0.04,
    this.vibratoDepth = 0.004,
    this.vibratoHz = 5.2,
  });

  static const Map<InstrumentType, InstrumentVoice> _map = {
    // Quena: flauta andina de bisel en caña — fundamental cálida, ataque suave y vibrato expresivo.
    InstrumentType.quena: InstrumentVoice(
      [1.0, 0.36, 0.14, 0.05, 0.02],
      0.35,
      0.78,
      attackSeconds: 0.045,
      breathNoise: 0.045,
      vibratoDepth: 0.0055,
      vibratoHz: 5.4,
    ),
    // Zampoña (Siku): tubos cerrados — dominan armónicos impares (1º, 3º, 5º) con soplo aéreo inicial.
    InstrumentType.zampona: InstrumentVoice(
      [1.0, 0.05, 0.30, 0.02, 0.11],
      0.45,
      0.76,
      attackSeconds: 0.038,
      breathNoise: 0.085,
      vibratoDepth: 0.0025,
      vibratoHz: 4.5,
    ),
    // Tarka: aerófono de madera de timbre denso y rasposo ("tara") con armónicos ricos.
    InstrumentType.tarka: InstrumentVoice(
      [1.0, 0.50, 0.38, 0.24, 0.14],
      0.30,
      0.74,
      attackSeconds: 0.032,
      breathNoise: 0.06,
      vibratoDepth: 0.007,
      vibratoHz: 6.2,
    ),
  };

  static InstrumentVoice of(InstrumentType i) =>
      _map[i] ?? _map[InstrumentType.quena]!;
}

/// Nombre legible (español) de cada instrumento, para la UI.
const Map<InstrumentType, String> instrumentLabels = {
  InstrumentType.quena: 'Quena',
  InstrumentType.zampona: 'Zampoña',
  InstrumentType.tarka: 'Tarka',
};
