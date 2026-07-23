import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Una grabación guardada de la interpretación del usuario en una práctica.
class Recording {
  final String id;
  final String lessonId;
  final String lessonTitle;
  final int dateMillis;
  final double score;
  final int durationMs;
  final String filePath;

  const Recording({
    required this.id,
    required this.lessonId,
    required this.lessonTitle,
    required this.dateMillis,
    required this.score,
    required this.durationMs,
    required this.filePath,
  });

  DateTime get date => DateTime.fromMillisecondsSinceEpoch(dateMillis);

  Map<String, dynamic> toJson() => {
        'id': id,
        'lessonId': lessonId,
        'lessonTitle': lessonTitle,
        'dateMillis': dateMillis,
        'score': score,
        'durationMs': durationMs,
        'filePath': filePath,
      };

  factory Recording.fromJson(Map<String, dynamic> j) => Recording(
        id: (j['id'] ?? '') as String,
        lessonId: (j['lessonId'] ?? '') as String,
        lessonTitle: (j['lessonTitle'] ?? 'Lección') as String,
        dateMillis: (j['dateMillis'] ?? 0) as int,
        score: ((j['score'] ?? 0) as num).toDouble(),
        durationMs: (j['durationMs'] ?? 0) as int,
        filePath: (j['filePath'] ?? '') as String,
      );
}

/// Biblioteca local de grabaciones ("Mis grabaciones").
///
/// Copia el audio del directorio temporal a almacenamiento permanente
/// (`<Documentos>/recordings/`) y guarda la metadata como una lista JSON en
/// SharedPreferences. Es liviano y autocontenido: NO toca la base Drift
/// compartida (cache offline + outbox de prácticas).
class RecordingsService {
  static const _key = 'practice_recordings';

  Future<Directory> _recordingsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/recordings');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Guarda una grabación recién hecha: copia el archivo temporal a permanente
  /// y agrega su metadata. Devuelve la grabación creada (o null si falla o si el
  /// archivo temporal ya no existe).
  Future<Recording?> saveFromTemp({
    required String tempPath,
    required String lessonId,
    required String lessonTitle,
    required double score,
  }) async {
    try {
      final src = File(tempPath);
      if (!await src.exists()) return null;
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final dir = await _recordingsDir();
      // Preservar el formato real: .m4a (grabador manual) o .wav (stream del
      // mic mientras se detecta). Copiar con la extensión equivocada rompe el
      // reproductor y el MIME al compartir.
      final ext = tempPath.toLowerCase().endsWith('.wav') ? 'wav' : 'm4a';
      final destPath = '${dir.path}/recording_$id.$ext';
      // COPIAR (no mover): el reproductor de la pantalla de resultados sigue
      // usando el archivo temporal; este es la copia permanente.
      await src.copy(destPath);
      final durationMs = await _probeDurationMs(destPath);
      final rec = Recording(
        id: id,
        lessonId: lessonId,
        lessonTitle: lessonTitle,
        dateMillis: int.parse(id),
        score: score,
        durationMs: durationMs,
        filePath: destPath,
      );
      final list = await _readRaw();
      list.insert(0, rec.toJson());
      await _writeRaw(list);
      return rec;
    } catch (_) {
      return null;
    }
  }

  /// Todas las grabaciones (más nuevas primero). Descarta entradas cuyo archivo
  /// ya no existe (limpieza perezosa) y reescribe la lista si hubo cambios.
  Future<List<Recording>> getAll() async {
    final raw = await _readRaw();
    final recs = raw.map(Recording.fromJson).toList();
    final valid = <Recording>[];
    var changed = false;
    for (final r in recs) {
      if (r.filePath.isNotEmpty && await File(r.filePath).exists()) {
        valid.add(r);
      } else {
        changed = true; // archivo borrado por el SO o el usuario
      }
    }
    if (changed) await _writeRaw(valid.map((e) => e.toJson()).toList());
    valid.sort((a, b) => b.dateMillis.compareTo(a.dateMillis));
    return valid;
  }

  /// Borra una grabación (archivo + metadata).
  Future<void> delete(String id) async {
    final raw = await _readRaw();
    final remaining = <Map<String, dynamic>>[];
    for (final e in raw) {
      if (e['id'] == id) {
        try {
          final f = File((e['filePath'] ?? '') as String);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      } else {
        remaining.add(e);
      }
    }
    await _writeRaw(remaining);
  }

  Future<List<Map<String, dynamic>>> _readRaw() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_key);
    if (s == null || s.isEmpty) return [];
    try {
      final decoded = jsonDecode(s) as List<dynamic>;
      return decoded
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeRaw(List<Map<String, dynamic>> list) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(list));
  }

  /// Mejor esfuerzo: duración del audio vía audioplayers (0 si no se puede leer).
  Future<int> _probeDurationMs(String path) async {
    final player = AudioPlayer();
    final completer = Completer<int>();
    StreamSubscription<Duration>? sub;
    sub = player.onDurationChanged.listen((d) {
      if (!completer.isCompleted && d > Duration.zero) {
        completer.complete(d.inMilliseconds);
      }
    });
    try {
      await player.setSource(DeviceFileSource(path));
      final fromGetter = await player.getDuration();
      if (fromGetter != null &&
          fromGetter > Duration.zero &&
          !completer.isCompleted) {
        completer.complete(fromGetter.inMilliseconds);
      }
      return await completer.future
          .timeout(const Duration(seconds: 3), onTimeout: () => 0);
    } catch (_) {
      return 0;
    } finally {
      await sub.cancel();
      await player.dispose();
    }
  }
}
