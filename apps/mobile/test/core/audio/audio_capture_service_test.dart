import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/audio/audio_capture_service.dart';
import 'package:record/record.dart';

/// Recorder falso: falla [failures] veces en `startStream` y luego tiene éxito.
class _FakeRecorder implements AudioRecorder {
  _FakeRecorder({this.failures = 0, this.permission = true});

  int failures;
  final bool permission;
  int startCalls = 0;

  @override
  Future<bool> hasPermission({bool request = true}) async => permission;

  @override
  Future<Stream<Uint8List>> startStream(RecordConfig config) async {
    startCalls++;
    if (failures > 0) {
      failures--;
      throw StateError('mic busy #$startCalls');
    }
    return const Stream<Uint8List>.empty();
  }

  @override
  Future<String?> stop() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CircularAudioBuffer [SUB-01-A]', () {
    test('escribe y lee muestras recientes correctamente', () {
      final buffer = CircularAudioBuffer(capacity: 10);
      final samples = Float32List.fromList([0.1, 0.2, 0.3, 0.4, 0.5]);

      buffer.write(samples);
      expect(buffer.availableSamples, 5);

      final read = buffer.readRecent(3);
      expect(read.length, 3);
      expect(read[0], closeTo(0.3, 1e-5));
      expect(read[1], closeTo(0.4, 1e-5));
      expect(read[2], closeTo(0.5, 1e-5));
    });

    test('sobrescribe circularmente cuando se supera la capacidad máxima', () {
      final buffer = CircularAudioBuffer(capacity: 4);
      buffer.write(Float32List.fromList([1.0, 2.0, 3.0, 4.0]));
      expect(buffer.availableSamples, 4);

      // Escribir 2 muestras más -> expulsa 1.0 y 2.0
      buffer.write(Float32List.fromList([5.0, 6.0]));
      expect(buffer.availableSamples, 4);

      final read = buffer.readRecent(4);
      expect(read, [3.0, 4.0, 5.0, 6.0]);
    });

    test('clear() reinicia índices y limpia muestras', () {
      final buffer = CircularAudioBuffer(capacity: 8);
      buffer.write(Float32List.fromList([0.9, 0.8, 0.7]));
      expect(buffer.availableSamples, 3);

      buffer.clear();
      expect(buffer.availableSamples, 0);
      final read = buffer.readRecent(3);
      expect(read, [0.0, 0.0, 0.0]);
    });
  });

  group('AudioCaptureService [SUB-01-A]', () {
    test('construye con buffer circular de tamaño configurable', () {
      final service = AudioCaptureService(circularBufferCapacity: 2048);
      expect(service.isCapturing, isFalse);
      expect(service.circularBuffer.capacity, 2048);
    });

    test('pcmAudioStream expone stream de Float32List broadcast', () {
      final service = AudioCaptureService();
      final stream1 = service.pcmAudioStream;
      final stream2 = service.pcmAudioStream;
      expect(stream1, isNotNull);
      expect(stream2, isNotNull);
    });
  });

  group('AudioCaptureService backoff [SUB-01-A / #118]', () {
    late List<Duration> delays;
    Future<void> fakeDelay(Duration d) async => delays.add(d);

    setUp(() => delays = []);

    test('reintenta con backoff exponencial acotado y tiene éxito', () async {
      final recorder = _FakeRecorder(failures: 2);
      final service = AudioCaptureService(
        recorder: recorder,
        maxRetries: 4,
        baseRetryDelay: const Duration(milliseconds: 100),
        maxRetryDelay: const Duration(milliseconds: 150),
        retryDelay: fakeDelay,
      );
      final states = <CaptureRetryState>[];
      service.retryStateStream.listen(states.add);

      await service.startCapture();
      await Future<void>.delayed(Duration.zero);

      expect(recorder.startCalls, 3);
      expect(service.isCapturing, isTrue);
      expect(delays, const [
        Duration(milliseconds: 100),
        Duration(milliseconds: 150), // acotado por maxRetryDelay
      ]);
      expect(states.map((s) => s.status), [
        CaptureRetryStatus.retrying,
        CaptureRetryStatus.retrying,
        CaptureRetryStatus.idle,
      ]);
      expect(states.first.attempt, 1);
      expect(service.retryState.status, CaptureRetryStatus.idle);
      await service.dispose();
    });

    test(
      'al agotar reintentos emite exhausted y lanza la causa real',
      () async {
        final recorder = _FakeRecorder(failures: 99);
        final service = AudioCaptureService(
          recorder: recorder,
          maxRetries: 3,
          baseRetryDelay: const Duration(milliseconds: 10),
          retryDelay: fakeDelay,
        );

        await expectLater(
          service.startCapture(),
          throwsA(
            isA<AudioHardwareException>().having(
              (e) => e.message,
              'message',
              contains('mic busy #4'),
            ),
          ),
        );

        expect(recorder.startCalls, 4); // 1 intento + 3 reintentos
        expect(delays, const [
          Duration(milliseconds: 10),
          Duration(milliseconds: 20),
          Duration(milliseconds: 40),
        ]);
        expect(service.retryState.status, CaptureRetryStatus.exhausted);
        expect(
          service.retryState.lastError.toString(),
          contains('mic busy #4'),
        );
        expect(service.isCapturing, isFalse);
      },
    );

    test('PermissionDeniedException no se reintenta', () async {
      final recorder = _FakeRecorder(permission: false);
      final service = AudioCaptureService(
        recorder: recorder,
        retryDelay: fakeDelay,
      );

      await expectLater(
        service.startCapture(),
        throwsA(isA<PermissionDeniedException>()),
      );
      expect(delays, isEmpty);
      expect(recorder.startCalls, 0);
    });

    test('stopCapture cancela los reintentos pendientes', () async {
      final recorder = _FakeRecorder(failures: 99);
      final gate = Completer<void>();
      final service = AudioCaptureService(
        recorder: recorder,
        maxRetries: 5,
        retryDelay: (_) => gate.future,
      );

      final start = service.startCapture();
      await Future<void>.delayed(Duration.zero);
      expect(service.retryState.status, CaptureRetryStatus.retrying);

      await service.stopCapture();
      gate.complete();
      await start; // termina sin lanzar

      expect(recorder.startCalls, 1);
      expect(service.isCapturing, isFalse);
      expect(service.retryState.status, CaptureRetryStatus.idle);
    });
  });
}
