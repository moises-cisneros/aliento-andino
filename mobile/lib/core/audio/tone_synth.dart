import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import 'instrument.dart';

/// Sintetizador de tonos SIN assets: genera el WAV de una nota en memoria
/// (armónicos + envolvente según el [Instrument] elegido) y lo reproduce con
/// audioplayers. Así la app "suena" al tocar/escuchar, sin soundfonts ni samples.
class ToneSynth {
  static const int _sampleRate = 44100;

  /// Instrumento/timbre actual. Se puede cambiar en caliente (el cache está
  /// segmentado por instrumento, así que no hay que limpiarlo).
  Instrument instrument;

  ToneSynth({this.instrument = Instrument.piano});

  // Pool de reproductores para permitir notas/acordes superpuestos. El
  // constructor por defecto genera un playerId único por reproductor.
  final List<AudioPlayer> _pool = List.generate(8, (_) => AudioPlayer());
  int _next = 0;
  int _epoch = 0; // se incrementa al frenar, para cancelar plays en vuelo
  final Map<String, Uint8List> _cache = {};

  static final RegExp _noteRe = RegExp(r'^([A-Ga-g])([#b]?)(\d)$');
  static const Map<String, int> _pitch = {
    'C': 0,
    'D': 2,
    'E': 4,
    'F': 5,
    'G': 7,
    'A': 9,
    'B': 11,
  };

  static double? _freq(String note) {
    final m = _noteRe.firstMatch(note.trim());
    if (m == null) return null;
    var semis = _pitch[m.group(1)!.toUpperCase()]!;
    if (m.group(2) == '#') semis++;
    if (m.group(2) == 'b') semis--;
    final midi = semis + (int.parse(m.group(3)!) + 1) * 12;
    return 440.0 * math.pow(2, (midi - 69) / 12.0);
  }

  Uint8List _wavFor(String note, double seconds) {
    // El cache se segmenta por instrumento para no devolver WAVs de otro timbre.
    final key = '${instrument.index}:$note:${seconds.toStringAsFixed(2)}';
    final cached = _cache[key];
    if (cached != null) return cached;

    final voice = InstrumentVoice.of(instrument);
    final harmonics = voice.harmonics;
    var weightSum = 0.0;
    for (final w in harmonics) {
      weightSum += w;
    }
    if (weightSum <= 0) weightSum = 1.0; // evita división por cero

    final freq = _freq(note) ?? 440.0;
    final n = (_sampleRate * seconds).round();
    // Fade-out lineal en los últimos ~6 ms: evita el "click" al cortar la nota
    // (notorio en timbres sostenidos como el órgano, que no decae solo).
    final fadeLen = math.min(n, (_sampleRate * 0.006).round());
    final samples = Int16List(n);
    for (var i = 0; i < n; i++) {
      final t = i / _sampleRate;
      final env = math.exp(-voice.decay * t / seconds);
      var v = 0.0;
      for (var h = 0; h < harmonics.length; h++) {
        final w = harmonics[h];
        if (w == 0) continue;
        v += w * math.sin(2 * math.pi * freq * (h + 1) * t);
      }
      var amp = v / weightSum * env * voice.gain;
      final tail = n - i;
      if (fadeLen > 0 && tail < fadeLen) amp *= tail / fadeLen;
      samples[i] = (amp * 32767).round().clamp(-32768, 32767);
    }
    final bytes = _wrapWav(samples);
    if (_cache.length > 256) _cache.clear(); // tope simple de memoria
    _cache[key] = bytes;
    return bytes;
  }

  Uint8List _wrapWav(Int16List samples) {
    final dataLen = samples.length * 2;
    final b = BytesBuilder();
    void str(String s) => b.add(s.codeUnits);
    void u32(int v) =>
        b.add([v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff, (v >> 24) & 0xff]);
    void u16(int v) => b.add([v & 0xff, (v >> 8) & 0xff]);
    str('RIFF');
    u32(36 + dataLen);
    str('WAVE');
    str('fmt ');
    u32(16);
    u16(1); // PCM
    u16(1); // mono
    u32(_sampleRate);
    u32(_sampleRate * 2); // byte rate
    u16(2); // block align
    u16(16); // bits
    str('data');
    u32(dataLen);
    b.add(samples.buffer.asUint8List(0, dataLen));
    return b.toBytes();
  }

  /// Reproduce una nota (ej. "C4"). [velocity] 0..1 controla el volumen.
  Future<void> play(
    String note, {
    double seconds = 0.7,
    double velocity = 0.9,
  }) async {
    if (note == 'REST' || _freq(note) == null) return;
    final bytes = _wavFor(note, seconds);
    final epoch = _epoch;
    final player = _pool[_next];
    _next = (_next + 1) % _pool.length;
    try {
      await player.stop();
      if (epoch != _epoch) return; // se frenó mientras esperábamos
      await player.setVolume(velocity.clamp(0.05, 1.0));
      if (epoch != _epoch) return;
      await player.play(BytesSource(bytes));
    } catch (_) {
      // Si un reproductor falla, no rompemos la práctica.
    }
  }

  Future<void> stopAll() async {
    _epoch++; // cancela cualquier play() en vuelo
    for (final p in _pool) {
      try {
        await p.stop();
      } catch (_) {}
    }
  }

  Future<void> dispose() async {
    for (final p in _pool) {
      try {
        await p.dispose();
      } catch (_) {}
    }
  }
}
