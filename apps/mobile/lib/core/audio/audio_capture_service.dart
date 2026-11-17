import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';

/// Excepción lanzada cuando el usuario deniega el permiso de micrófono.
class PermissionDeniedException implements Exception {
  final String message;
  const PermissionDeniedException([
    this.message = 'Permiso de micrófono denegado',
  ]);

  @override
  String toString() => 'PermissionDeniedException: $message';
}

/// Excepción lanzada ante fallos en la capa de hardware o inicialización del micrófono.
class AudioHardwareException implements Exception {
  final String message;
  const AudioHardwareException([
    this.message = 'Fallo de hardware o stream de audio no disponible',
  ]);

  @override
  String toString() => 'AudioHardwareException: $message';
}

/// Buffer circular determinista en memoria para acumulación continua de muestras PCM Float32.
///
/// Previene la pérdida de muestras y suministra ventanas fijas (ej. 1024 a 2048 muestras)
/// para los algoritmos acústicos (como YIN) sin realocaciones constantes en heap.
class CircularAudioBuffer {
  final int capacity;
  final Float32List _buffer;
  int _writeIndex = 0;
  int _availableSamples = 0;

  CircularAudioBuffer({this.capacity = 4096}) : _buffer = Float32List(capacity);

  int get availableSamples => _availableSamples;

  /// Escribe un lote de muestras en el buffer circular sobrescribiendo los datos más antiguos si se excede la capacidad.
  void write(Float32List samples) {
    for (int i = 0; i < samples.length; i++) {
      _buffer[_writeIndex] = samples[i];
      _writeIndex = (_writeIndex + 1) % capacity;
      if (_availableSamples < capacity) {
        _availableSamples++;
      }
    }
  }

  /// Lee las últimas [length] muestras consecutivas sin vaciar el buffer.
  Float32List readRecent(int length) {
    final result = Float32List(length);
    if (_availableSamples == 0) return result;

    final readCount = length.clamp(0, _availableSamples);
    final startIndex = (_writeIndex - readCount + capacity) % capacity;

    for (int i = 0; i < readCount; i++) {
      result[i] = _buffer[(startIndex + i) % capacity];
    }
    return result;
  }

  /// Reinicia el estado del buffer.
  void clear() {
    _writeIndex = 0;
    _availableSamples = 0;
    _buffer.fillRange(0, capacity, 0.0);
  }
}

/// Servicio de captura continua de audio desde el micrófono a 44.1 kHz.
///
/// Emite chunks normalizados en un `Stream<Float32List>` de 1024 muestras
/// desacoplando la adquisición acústica del hilo de renderizado de UI.
class AudioCaptureService {
  final AudioRecorder? _customRecorder;
  AudioRecorder? _internalRecorder;
  final CircularAudioBuffer _circularBuffer;
  StreamController<Float32List>? _streamController;
  StreamSubscription<Uint8List>? _rawAudioSubscription;
  bool _isCapturing = false;

  AudioCaptureService({
    AudioRecorder? recorder,
    int circularBufferCapacity = 4096,
  }) : _customRecorder = recorder,
       _circularBuffer = CircularAudioBuffer(capacity: circularBufferCapacity);

  AudioRecorder get _recorder =>
      _customRecorder ?? (_internalRecorder ??= AudioRecorder());

  bool get isCapturing => _isCapturing;
  CircularAudioBuffer get circularBuffer => _circularBuffer;

  /// Stream reactivo de chunks de audio PCM Float32 (tamaño típico: 1024 muestras).
  Stream<Float32List> get pcmAudioStream {
    _streamController ??= StreamController<Float32List>.broadcast();
    return _streamController!.stream;
  }

  /// Inicia la captura de audio continua a través del micrófono.
  ///
  /// Lanza [PermissionDeniedException] si no se cuenta con permiso de grabación.
  /// Lanza [AudioHardwareException] si la configuración del micrófono falla.
  Future<void> startCapture({
    int sampleRate = 44100,
    int bufferSize = 1024,
  }) async {
    if (_isCapturing) return;

    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        throw const PermissionDeniedException();
      }

      _streamController ??= StreamController<Float32List>.broadcast();
      _circularBuffer.clear();

      final recordStream = await _recorder.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: sampleRate,
          numChannels: 1,
        ),
      );

      _isCapturing = true;

      _rawAudioSubscription = recordStream.listen(
        (uint8Data) {
          // Convertir PCM 16-bit signed Little Endian a Float32List normalizado [-1.0, 1.0]
          final byteData = ByteData.sublistView(uint8Data);
          final sampleCount = byteData.lengthInBytes ~/ 2;
          final floatSamples = Float32List(sampleCount);

          for (int i = 0; i < sampleCount; i++) {
            final pcm16 = byteData.getInt16(i * 2, Endian.little);
            floatSamples[i] = pcm16 / 32768.0;
          }

          _circularBuffer.write(floatSamples);

          // Si hay suficientes muestras para una ventana completa, emitir
          if (_circularBuffer.availableSamples >= bufferSize) {
            final chunk = _circularBuffer.readRecent(bufferSize);
            _streamController?.add(chunk);
          }
        },
        onError: (error) {
          _streamController?.addError(AudioHardwareException(error.toString()));
        },
        cancelOnError: false,
      );
    } catch (e) {
      _isCapturing = false;
      if (e is PermissionDeniedException) rethrow;
      throw AudioHardwareException('Error al inicializar micrófono: $e');
    }
  }

  /// Detiene la captura y libera el hardware de audio.
  Future<void> stopCapture() async {
    if (!_isCapturing) return;
    _isCapturing = false;

    await _rawAudioSubscription?.cancel();
    _rawAudioSubscription = null;

    try {
      await _recorder.stop();
    } catch (_) {}

    _circularBuffer.clear();
  }

  /// Limpia los recursos y cierra los controladores de stream.
  Future<void> dispose() async {
    await stopCapture();
    await _streamController?.close();
    _streamController = null;
    try {
      _internalRecorder?.dispose();
    } catch (_) {}
  }
}
