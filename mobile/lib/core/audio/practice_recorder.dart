import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Graba el audio de la práctica a un archivo temporal (AAC/.m4a) para que el
/// usuario pueda reescuchar su interpretación. Es independiente de la detección
/// por micrófono (que también usa el mic), así que solo debe usarse cuando esa
/// detección está APAGADA, para no pelear por el micrófono.
class PracticeRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  String? _path;
  bool _recording = false;

  bool get isRecording => _recording;

  /// Empieza a grabar. Devuelve false si no hay permiso de micrófono.
  Future<bool> start() async {
    if (_recording) return true;
    if (!await _recorder.hasPermission()) return false;
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/practice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        numChannels: 1,
        bitRate: 128000,
      ),
      path: path,
    );
    _path = path;
    _recording = true;
    return true;
  }

  /// Detiene y devuelve el path del archivo grabado (o null si no hay nada).
  Future<String?> stop() async {
    if (!_recording) return _path;
    _recording = false;
    try {
      final p = await _recorder.stop();
      _path = p ?? _path;
    } catch (_) {}
    return _path;
  }

  Future<void> dispose() async {
    try {
      if (_recording) await _recorder.stop();
    } catch (_) {}
    try {
      await _recorder.dispose();
    } catch (_) {}
  }
}
