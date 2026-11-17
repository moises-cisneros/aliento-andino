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

/// Instrumentos/timbres disponibles para el sintetizador ([ToneSynth]).
///
/// Quena, Zampoña y Tarka son los instrumentos andinos canónicos principales.
/// Se mantienen los restantes por compatibilidad con generadores de tono.
enum Instrument { quena, zampona, tarka, piano, electricPiano, organ, synth }

/// Perfil sonoro de un instrumento.
class InstrumentVoice {
  /// Pesos de los armónicos (índice 0 = fundamental, 1 = 2º armónico, …).
  final List<double> harmonics;

  /// Constante de decaimiento exponencial de la envolvente.
  final double decay;

  /// Ganancia maestra (0..1).
  final double gain;

  const InstrumentVoice(this.harmonics, this.decay, this.gain);

  static const Map<Instrument, InstrumentVoice> _map = {
    // Quena: sonido cálido con armónicos pares e impares y aire suave.
    Instrument.quena: InstrumentVoice([1.0, 0.6, 0.35, 0.2, 0.1], 1.8, 0.7),
    // Zampoña: flauta de pan con armónicos impares pronunciados y ataque aéreo.
    Instrument.zampona: InstrumentVoice([1.0, 0.1, 0.5, 0.05, 0.25], 1.2, 0.65),
    // Tarka: aerófono de madera con sonido rasposo y ricos armónicos superiores.
    Instrument.tarka: InstrumentVoice([1.0, 0.8, 0.7, 0.5, 0.3], 1.0, 0.7),
    // Piano
    Instrument.piano: InstrumentVoice([1.0, 0.5, 0.25], 3.2, 0.6),
    // Piano eléctrico
    Instrument.electricPiano: InstrumentVoice(
      [1.0, 0.0, 0.15, 0.0, 0.08],
      2.4,
      0.6,
    ),
    // Órgano
    Instrument.organ: InstrumentVoice([1.0, 1.0, 0.6, 0.4], 0.05, 0.45),
    // Sintetizador
    Instrument.synth: InstrumentVoice([1.0, 0.5, 0.33, 0.25, 0.2], 1.4, 0.5),
  };

  static InstrumentVoice of(Instrument i) => _map[i] ?? _map[Instrument.quena]!;
}

/// Nombre legible (español) de cada instrumento, para la UI.
const Map<Instrument, String> instrumentLabels = {
  Instrument.quena: 'Quena',
  Instrument.zampona: 'Zampoña',
  Instrument.tarka: 'Tarka',
  Instrument.piano: 'Piano',
  Instrument.electricPiano: 'Piano eléctrico',
  Instrument.organ: 'Órgano',
  Instrument.synth: 'Sintetizador',
};
