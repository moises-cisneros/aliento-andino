import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';
import 'package:record/record.dart';

import 'chord_detector.dart';

/// Resultado de una detección de pitch.
class DetectedNote {
  final String note; // "C4", "F#4", "Bb3"
  final double frequency;
  final double confidence; // 0-1
  final int? midiNumber;

  const DetectedNote({
    required this.note,
    required this.frequency,
    required this.confidence,
    this.midiNumber,
  });
}

/// Resultado de una detección polifónica.
class ChordDetectionResult {
  final List<DetectedPitch> pitches;
  final ChordMatch? match;

  const ChordDetectionResult({required this.pitches, this.match});
}

/// Detector de notas en tiempo real usando algoritmo YIN sobre audio del micrófono.
///
/// Pipeline:
///   mic stream (PCM 16) → buffer 4096 samples → YIN pitch detection
///   → freq → nota musical (con threshold de confianza)
///
/// Para piano (rango útil ~27Hz a ~4200Hz) y voz/silbidos, YIN es suficiente.
/// Latencia esperada: 80-150ms.
class NoteDetector {
  final AudioRecorder _recorder = AudioRecorder();
  late final PitchDetector _pitchDetector;
  final ChordDetector _chordDetector = ChordDetector();

  StreamSubscription<Uint8List>? _audioSubscription;
  final _noteController = StreamController<DetectedNote>.broadcast();
  final _chordController = StreamController<ChordDetectionResult>.broadcast();

  static const int _sampleRate = 44100;
  static const int _bufferSize = 4096; // ~93ms a 44.1kHz
  // Threshold de confianza alto para evitar ruido ambiente.
  // YIN devuelve valores cerca de 1.0 para tonos puros y < 0.9 para ruido.
  static const double _minConfidence = 0.92;
  // Frecuencia mínima aceptada: C3 (~130.81 Hz). Por debajo es típicamente
  // rumble/vibración/voces graves, no piano.
  static const double _minFreq = 130.0;
  static const double _maxFreq = 4200.0;

  // Buffer interno para acumular samples (monophonic YIN)
  final List<double> _sampleBuffer = [];

  // Buffer rodante para chord detection (FFT requiere 8192 samples)
  final List<double> _chordBuffer = [];
  static const int _chordWindowSize = 8192;
  DateTime _lastChordEmit = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _chordInterval = Duration(milliseconds: 400);
  bool _chordEnabled = false;

  // Anti-repetición por ONSET: la misma nota no se vuelve a emitir hasta que
  // haya habido una "liberación" (silencio) entre medio. Así una nota sostenida
  // NO avanza varias notas, y una repetición real (re-ataque) sí cuenta.
  String? _lastEmittedNote;
  bool _released = true; // empieza liberado para que la 1ª nota emita
  int _silenceFrames = 0;
  static const int _minSilenceFrames = 2; // ~186ms a 44.1kHz/4096

  // Estabilidad: pedir que la misma nota se detecte en N frames consecutivos
  // antes de emitirla. Filtra picos de ruido ambiente que tienden a saltar
  // entre frecuencias aleatorias, mientras que una nota real es sostenida.
  String? _candidateNote;
  int _candidateCount = 0;
  static const int _minStableFrames = 2;

  // Grabación opcional del MISMO stream del micrófono a un archivo WAV. Permite
  // TOCAR EN VIVO (detección) y GRABAR a la vez, con una sola apertura del mic
  // (no se puede abrir el micrófono dos veces). El PCM crudo se va volcando a un
  // archivo temporal y al cerrar se arma el WAV con su cabecera.
  IOSink? _wavSink;
  String? _wavPath;
  String? _rawPath;
  int _wavBytes = 0;

  bool get isRecording => _wavSink != null;

  NoteDetector() {
    _pitchDetector = PitchDetector(
      audioSampleRate: _sampleRate.toDouble(),
      bufferSize: _bufferSize,
    );
  }

  /// Stream con cada nota detectada (filtradas por confianza y debouncing).
  Stream<DetectedNote> get notes => _noteController.stream;

  /// Stream con detecciones polifónicas (acordes). Solo emite cuando
  /// `chordDetectionEnabled` está activo.
  Stream<ChordDetectionResult> get chords => _chordController.stream;

  /// Activa o desactiva la detección polifónica. Cuando se activa, el detector
  /// empieza a acumular buffer y a correr FFT periódicamente. Cuando se
  /// desactiva, se libera el buffer.
  void setChordDetectionEnabled(bool enabled) {
    if (_chordEnabled == enabled) return;
    _chordEnabled = enabled;
    if (!enabled) _chordBuffer.clear();
  }

  /// Pide permiso de mic y arranca a escuchar. Retorna `true` si arrancó OK.
  Future<bool> start() async {
    // Permiso
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      debugPrint('NoteDetector: permiso de mic denegado');
      return false;
    }

    if (!await _recorder.hasPermission()) {
      return false;
    }

    // Iniciar stream PCM 16
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: 1,
      ),
    );

    _audioSubscription = stream.listen(_onAudioChunk);
    debugPrint('NoteDetector: escuchando');
    return true;
  }

  /// Empieza a guardar el audio del micrófono a [wavPath] (WAV PCM16 mono)
  /// mientras se sigue detectando. Idempotente.
  Future<void> startRecording(String wavPath) async {
    if (_wavSink != null) return;
    _wavPath = wavPath;
    _rawPath = '$wavPath.pcm';
    _wavBytes = 0;
    _wavSink = File(_rawPath!).openWrite();
  }

  /// Cierra la grabación y arma el WAV final. Devuelve su path (o el último
  /// finalizado si ya estaba cerrada). Idempotente.
  Future<String?> stopRecording() async {
    final sink = _wavSink;
    if (sink == null) return _wavPath;
    _wavSink = null;
    try {
      await sink.flush();
      await sink.close();
      await _finalizeWav();
    } catch (e) {
      debugPrint('NoteDetector: error finalizando WAV: $e');
    } finally {
      try {
        final raw = File(_rawPath!);
        if (await raw.exists()) await raw.delete();
      } catch (_) {}
    }
    return _wavPath;
  }

  /// Arma el archivo WAV final: cabecera de 44 bytes + el PCM crudo acumulado.
  Future<void> _finalizeWav() async {
    final out = File(_wavPath!).openWrite();
    out.add(_wavHeader(_wavBytes));
    await out.addStream(File(_rawPath!).openRead());
    await out.flush();
    await out.close();
  }

  /// Cabecera WAV PCM (44 bytes) para [dataLen] bytes de audio PCM16 mono.
  Uint8List _wavHeader(int dataLen) {
    const channels = 1;
    const bits = 16;
    final byteRate = _sampleRate * channels * (bits ~/ 8);
    final blockAlign = channels * (bits ~/ 8);
    final h = ByteData(44);
    void setStr(int off, String s) {
      for (var i = 0; i < s.length; i++) {
        h.setUint8(off + i, s.codeUnitAt(i));
      }
    }

    setStr(0, 'RIFF');
    h.setUint32(4, 36 + dataLen, Endian.little);
    setStr(8, 'WAVE');
    setStr(12, 'fmt ');
    h.setUint32(16, 16, Endian.little);
    h.setUint16(20, 1, Endian.little); // PCM
    h.setUint16(22, channels, Endian.little);
    h.setUint32(24, _sampleRate, Endian.little);
    h.setUint32(28, byteRate, Endian.little);
    h.setUint16(32, blockAlign, Endian.little);
    h.setUint16(34, bits, Endian.little);
    setStr(36, 'data');
    h.setUint32(40, dataLen, Endian.little);
    return h.buffer.asUint8List();
  }

  Future<void> stop() async {
    // Finalizar cualquier grabación en curso antes de soltar el micrófono.
    if (_wavSink != null) {
      await stopRecording();
    }
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    try {
      await _recorder.stop();
    } catch (_) {}
    _sampleBuffer.clear();
    _chordBuffer.clear();
    _lastEmittedNote = null;
    _released = true;
    _silenceFrames = 0;
    _candidateNote = null;
    _candidateCount = 0;
  }

  Future<void> dispose() async {
    // Cada paso va aislado: si uno falla, el resto igual se libera. Antes, si
    // _noteController.close() lanzaba, _recorder.dispose() nunca corría y el
    // micrófono quedaba tomado.
    try {
      await stop();
    } catch (_) {}
    try {
      await _noteController.close();
    } catch (_) {}
    try {
      await _chordController.close();
    } catch (_) {}
    try {
      await _recorder.dispose();
    } catch (_) {}
  }

  /// Procesa un chunk de audio PCM 16 (little-endian).
  void _onAudioChunk(Uint8List bytes) {
    // Si está grabando, volcar el PCM crudo (el WAV se arma al cerrar). IOSink
    // es ordenado y no bloqueante; el chequeo de null evita escribir tras cerrar.
    if (_wavSink != null) {
      _wavSink!.add(bytes);
      _wavBytes += bytes.length;
    }

    // Convertir bytes PCM 16-bit a floats normalizados [-1, 1]
    final samples = _bytesToFloats(bytes);
    _sampleBuffer.addAll(samples);

    // Procesar cuando tengamos suficiente (monophonic YIN)
    while (_sampleBuffer.length >= _bufferSize) {
      final chunk = _sampleBuffer.sublist(0, _bufferSize);
      _sampleBuffer.removeRange(0, _bufferSize);
      _analyzeBuffer(chunk);
    }

    // Acumular para chord detection si está activo
    if (_chordEnabled) {
      _chordBuffer.addAll(samples);
      // Mantener ventana rodante (descartar lo más viejo)
      if (_chordBuffer.length > _chordWindowSize * 2) {
        _chordBuffer.removeRange(
          0,
          _chordBuffer.length - _chordWindowSize,
        );
      }
      final now = DateTime.now();
      if (_chordBuffer.length >= _chordWindowSize &&
          now.difference(_lastChordEmit) >= _chordInterval) {
        _lastChordEmit = now;
        _analyzeChordBuffer();
      }
    }
  }

  /// Corre FFT polifónica sobre el buffer acumulado y emite resultado.
  void _analyzeChordBuffer() {
    try {
      final pitches = _chordDetector.detectNotes(_chordBuffer);
      if (pitches.isEmpty) return;
      final match = _chordDetector.identifyChord(pitches);
      _chordController.add(
        ChordDetectionResult(pitches: pitches, match: match),
      );
    } catch (e) {
      debugPrint('NoteDetector: error en chord detection: $e');
    }
  }

  List<double> _bytesToFloats(Uint8List bytes) {
    // PCM 16-bit signed little-endian
    final samples = <double>[];
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      final low = bytes[i];
      final high = bytes[i + 1];
      int sample = (high << 8) | low;
      if (sample >= 0x8000) sample -= 0x10000;
      samples.add(sample / 32768.0);
    }
    return samples;
  }

  Future<void> _analyzeBuffer(List<double> samples) async {
    try {
      final result = await _pitchDetector.getPitchFromFloatBuffer(samples);
      final freq = result.pitch;
      final pitched = result.pitched &&
          result.probability >= _minConfidence &&
          freq >= _minFreq &&
          freq <= _maxFreq;

      if (!pitched) {
        // Silencio/ruido: tras unos frames marcamos "liberado" para permitir
        // que la MISMA nota se vuelva a contar en el próximo ataque.
        _silenceFrames++;
        if (_silenceFrames >= _minSilenceFrames) {
          _released = true;
          _candidateNote = null;
          _candidateCount = 0;
        }
        return;
      }
      _silenceFrames = 0;

      final note = _frequencyToNote(freq);
      _maybeEmit(DetectedNote(
        note: note,
        frequency: freq,
        confidence: result.probability,
        midiNumber: _frequencyToMidi(freq),
      ));
    } catch (e) {
      debugPrint('NoteDetector: error analizando buffer: $e');
    }
  }

  /// Convierte una frecuencia a nombre de nota (C4, F#4, etc.).
  /// Usa A4=440Hz como referencia.
  String _frequencyToNote(double freq) {
    const noteNames = [
      'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
    ];
    final midi = _frequencyToMidi(freq);
    final noteIdx = midi % 12;
    final octave = (midi / 12).floor() - 1;
    return '${noteNames[noteIdx]}$octave';
  }

  int _frequencyToMidi(double freq) {
    // MIDI: A4 (440Hz) = 69 ; semitono = freq * 2^(1/12)
    // formula: midi = 69 + 12 * log2(freq/440)
    return (69 + 12 * (math.log(freq / 440.0) / math.ln2)).round();
  }

  void _maybeEmit(DetectedNote note) {
    // Requisito de estabilidad: la nota tiene que repetirse N frames seguidos.
    // Esto descarta picos de ruido (que saltan entre frecuencias) y deja pasar
    // notas reales (que son sostenidas).
    if (note.note == _candidateNote) {
      _candidateCount++;
    } else {
      _candidateNote = note.note;
      _candidateCount = 1;
    }
    if (_candidateCount < _minStableFrames) return;

    // Onset gating: una nota DISTINTA a la última siempre cuenta (es un evento
    // nuevo). La MISMA nota solo se vuelve a contar si hubo una liberación
    // (silencio) en el medio → evita avances dobles por una nota sostenida.
    if (note.note == _lastEmittedNote && !_released) return;

    _lastEmittedNote = note.note;
    _released = false;
    _noteController.add(note);
  }
}
