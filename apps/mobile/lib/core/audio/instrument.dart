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

/// Perfil sonoro de un instrumento.
class InstrumentVoice {
  /// Pesos de los armónicos (índice 0 = fundamental, 1 = 2º armónico, …).
  final List<double> harmonics;

  /// Constante de decaimiento exponencial de la envolvente.
  final double decay;

  /// Ganancia maestra (0..1).
  final double gain;

  const InstrumentVoice(this.harmonics, this.decay, this.gain);

  static const Map<InstrumentType, InstrumentVoice> _map = {
    // Quena: sonido cálido con armónicos pares e impares y aire suave.
    InstrumentType.quena: InstrumentVoice([1.0, 0.6, 0.35, 0.2, 0.1], 1.8, 0.7),
    // Zampoña: flauta de pan con armónicos impares pronunciados y ataque aéreo.
    InstrumentType.zampona: InstrumentVoice(
      [1.0, 0.1, 0.5, 0.05, 0.25],
      1.2,
      0.65,
    ),
    // Tarka: aerófono de madera con sonido rasposo y ricos armónicos superiores.
    InstrumentType.tarka: InstrumentVoice([1.0, 0.8, 0.7, 0.5, 0.3], 1.0, 0.7),
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
