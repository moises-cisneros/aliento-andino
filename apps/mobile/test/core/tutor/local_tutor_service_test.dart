import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/core/audio/instrument.dart';
import 'package:mobile/core/tutor/edge_ai_slm_runtime.dart';
import 'package:mobile/core/tutor/local_slm_engine.dart';
import 'package:mobile/core/tutor/local_tutor_service.dart';
import 'package:mobile/core/tutor/tutor_prompt_builder.dart';
import 'package:mobile/features/tutor/presentation/widgets/local_tutor_section.dart';

class _FakeGenerator implements SlmGenerator {
  final String reply;
  final Duration delay;
  bool closed = false;
  String? lastPrompt;

  _FakeGenerator(this.reply, {this.delay = Duration.zero});

  @override
  Future<String> generate(String prompt) async {
    lastPrompt = prompt;
    await Future<void>.delayed(delay);
    return reply;
  }

  @override
  Future<void> close() async => closed = true;
}

class _FakeStore implements SlmModelStore {
  bool installed;
  bool failInstall;
  int installCalls = 0;

  _FakeStore({this.installed = false, this.failInstall = false});

  @override
  String get modelRef => 'fake://model.task';

  @override
  Future<bool> isInstalled() async => installed;

  @override
  Future<void> install({void Function(int percent)? onProgress}) async {
    installCalls++;
    if (failInstall) throw StateError('network down');
    onProgress?.call(50);
    onProgress?.call(100);
    installed = true;
  }
}

const _summary = PracticeSummary(
  score: 72,
  correctNotes: 7,
  totalNotes: 10,
  wrongNotes: 2,
  missedNotes: 1,
);

LocalTutorService _service(
  _FakeStore store,
  _FakeGenerator generator, {
  Duration timeout = const Duration(seconds: 2),
}) {
  return LocalTutorService(
    store: store,
    engineFactory: () => LocalSlmEngine(
      runtime: EdgeAiSlmRuntime(loader: (_) async => generator),
      freeRamProvider: () => 4096,
      generationTimeout: timeout,
    ),
  );
}

void main() {
  group('sanitizeSlmReply', () {
    test(
      'repairs UTF-8 split into Latin-1 pairs without touching good text',
      () {
        expect(
          repairMojibake('música: AsegÃºrate de que estÃ© bien'),
          'música: Asegúrate de que esté bien',
        );
      },
    );

    test('strips markdown and list markers', () {
      expect(
        sanitizeSlmReply('1. **Respira** hondo\n2. Relaja los hombros'),
        'Respira hondo Relaja los hombros',
      );
    });

    test('removes literal \n sequences', () {
      expect(sanitizeSlmReply(r'\nHola. Sigue así.'), 'Hola. Sigue así.');
    });

    test('drops a dangling sentence when the token cap cut the reply', () {
      expect(
        sanitizeSlmReply(
          'Respira hondo. Relaja los hombros y el',
          truncated: true,
        ),
        'Respira hondo.',
      );
    });

    test('caps length at a sentence boundary', () {
      final long =
          '${List.filled(40, 'uno').join(' ')}. ${List.filled(40, 'dos').join(' ')}.';
      final out = sanitizeSlmReply(long, maxWords: 50);
      expect(out.endsWith('.'), isTrue);
      expect(out.split(' ').length, lessThanOrEqualTo(50));
    });
  });

  group('EdgeAiSlmRuntime', () {
    test('is not loaded until loadModel succeeds', () async {
      final runtime = EdgeAiSlmRuntime(
        loader: (_) async => _FakeGenerator('ok'),
      );
      expect(runtime.isLoaded, isFalse);
      await runtime.loadModel('x');
      expect(runtime.isLoaded, isTrue);
      expect(await runtime.generateResponse('hola'), 'ok');
    });

    test('generateResponse without a model throws StateError', () {
      final runtime = EdgeAiSlmRuntime(
        loader: (_) async => _FakeGenerator('ok'),
      );
      expect(() => runtime.generateResponse('hola'), throwsStateError);
    });

    test('dispose closes the generator and unloads', () async {
      final generator = _FakeGenerator('ok');
      final runtime = EdgeAiSlmRuntime(loader: (_) async => generator);
      await runtime.loadModel('x');
      runtime.dispose();
      expect(runtime.isLoaded, isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(generator.closed, isTrue);
    });
  });

  group('LocalTutorService', () {
    test('uses the model when it is installed', () async {
      final generator = _FakeGenerator('Respira profundo y suelta el aire.');
      final service = _service(_FakeStore(installed: true), generator);

      final text = await service.generateFeedback(
        _summary,
        InstrumentType.quena,
      );

      expect(text, 'Respira profundo y suelta el aire.');
      expect(generator.lastPrompt, contains('Quena'));
      expect(service.isUsingModel, isTrue);
      expect(service.lastFeedbackFromModel, isTrue);
    });

    test('falls back to rules when the model is not installed', () async {
      final generator = _FakeGenerator('should not be used');
      final service = _service(_FakeStore(installed: false), generator);

      final text = await service.generateFeedback(
        _summary,
        InstrumentType.zampona,
      );

      expect(text, isNotEmpty);
      expect(text, isNot('should not be used'));
      expect(generator.lastPrompt, isNull);
      expect(service.isUsingModel, isFalse);
    });

    test('falls back to rules when generation times out', () async {
      final generator = _FakeGenerator(
        'late answer',
        delay: const Duration(milliseconds: 200),
      );
      final service = _service(
        _FakeStore(installed: true),
        generator,
        timeout: const Duration(milliseconds: 20),
      );

      final text = await service.generateFeedback(
        _summary,
        InstrumentType.tarka,
      );

      expect(text, isNot('late answer'));
      expect(text, isNotEmpty);
      expect(service.isUsingModel, isTrue);
      expect(service.lastFeedbackFromModel, isFalse);
    });

    test('installModel downloads and switches to the model', () async {
      final store = _FakeStore(installed: false);
      final generator = _FakeGenerator('Consejo del modelo.');
      final service = _service(store, generator);
      final progress = <int>[];

      await service.generateFeedback(_summary, InstrumentType.quena);
      expect(service.isUsingModel, isFalse);

      await service.installModel(onProgress: progress.add);
      final text = await service.generateFeedback(
        _summary,
        InstrumentType.quena,
      );

      expect(progress, [50, 100]);
      expect(text, 'Consejo del modelo.');
      expect(service.isUsingModel, isTrue);
    });
  });

  group('LocalTutorSection', () {
    Future<void> pump(WidgetTester tester, LocalTutorService service) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LocalTutorSection(
                summary: _summary,
                instrument: InstrumentType.quena,
                service: service,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('offers the download when the model is missing', (
      tester,
    ) async {
      final service = _service(_FakeStore(), _FakeGenerator('x'));
      await pump(tester, service);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tutor_feedback_text')), findsOneWidget);
      expect(find.byKey(const Key('local_tutor_download')), findsOneWidget);
    });

    testWidgets('hides the download once the model is installed', (
      tester,
    ) async {
      final service = _service(
        _FakeStore(installed: true),
        _FakeGenerator('Consejo local.'),
      );
      await pump(tester, service);
      await tester.pumpAndSettle();

      expect(find.text('Consejo local.'), findsOneWidget);
      expect(find.byKey(const Key('local_tutor_download')), findsNothing);
    });

    testWidgets('shows an error when the download fails', (tester) async {
      final service = _service(
        _FakeStore(failInstall: true),
        _FakeGenerator('x'),
      );
      await pump(tester, service);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('local_tutor_download')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('local_tutor_error')), findsOneWidget);
      expect(find.byKey(const Key('local_tutor_download')), findsOneWidget);
    });
  });
}
