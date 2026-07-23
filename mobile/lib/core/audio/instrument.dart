/// Instrumentos/timbres disponibles para el sintetizador ([ToneSynth]).
///
/// Cada timbre se define por su serie de armónicos (pesos relativos, índice 0 =
/// fundamental) + la constante de decaimiento de la envolvente y la ganancia.
/// El [ToneSynth] genera el WAV en memoria con estos parámetros, así que cambiar
/// de instrumento no necesita assets.
enum Instrument { piano, electricPiano, organ, synth }

/// Perfil sonoro de un instrumento.
class InstrumentVoice {
  /// Pesos de los armónicos (índice 0 = fundamental, 1 = 2º armónico, …).
  final List<double> harmonics;

  /// Constante de decaimiento exponencial de la envolvente. Valores altos =
  /// decae rápido (piano); ~0 = casi sostenido (órgano).
  final double decay;

  /// Ganancia maestra (0..1).
  final double gain;

  const InstrumentVoice(this.harmonics, this.decay, this.gain);

  static const Map<Instrument, InstrumentVoice> _map = {
    // Piano: timbre original (fundamental + 2º + 3º, decaimiento medio).
    Instrument.piano: InstrumentVoice([1.0, 0.5, 0.25], 3.2, 0.6),
    // Piano eléctrico (tipo Rhodes): armónicos impares, decaimiento más suave.
    Instrument.electricPiano:
        InstrumentVoice([1.0, 0.0, 0.15, 0.0, 0.08], 2.4, 0.6),
    // Órgano: drawbars ricos, casi sin decaimiento (sostenido).
    Instrument.organ: InstrumentVoice([1.0, 1.0, 0.6, 0.4], 0.05, 0.45),
    // Sintetizador: más armónicos, brillante, decaimiento corto.
    Instrument.synth: InstrumentVoice([1.0, 0.5, 0.33, 0.25, 0.2], 1.4, 0.5),
  };

  static InstrumentVoice of(Instrument i) => _map[i] ?? _map[Instrument.piano]!;
}

/// Nombre legible (español) de cada instrumento, para la UI.
const Map<Instrument, String> instrumentLabels = {
  Instrument.piano: 'Piano',
  Instrument.electricPiano: 'Piano eléctrico',
  Instrument.organ: 'Órgano',
  Instrument.synth: 'Sintetizador',
};
