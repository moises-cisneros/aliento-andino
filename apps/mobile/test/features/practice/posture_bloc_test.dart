import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:mobile/core/audio/instrument.dart';
import 'package:mobile/features/practice/posture/pose_frame_source.dart';
import 'package:mobile/features/practice/posture/posture_scorer.dart';
import 'package:mobile/features/practice/posture/presentation/bloc/posture_bloc.dart';

class MockPoseFrameSource extends Mock implements PoseFrameSource {}

/// Construye un [PoseFrame] sintético con 33 landmarks de MediaPipe Pose.
PoseFrame buildFrame({
  double leftShoulderY = 0.40,
  double rightShoulderY = 0.40,
  double noseX = 0.50,
  double leftElbowX = 0.35,
  double leftElbowY = 0.55,
  double rightElbowX = 0.65,
  double rightElbowY = 0.55,
  double visibility = 0.95,
}) {
  final list = List<NormalizedLandmark>.filled(
    33,
    NormalizedLandmark(x: 0.5, y: 0.5, z: 0.0, visibility: visibility),
  );
  list[0] = NormalizedLandmark(
    x: noseX,
    y: 0.25,
    z: 0.0,
    visibility: visibility,
  );
  list[11] = NormalizedLandmark(
    x: 0.35,
    y: leftShoulderY,
    z: 0.0,
    visibility: visibility,
  );
  list[12] = NormalizedLandmark(
    x: 0.65,
    y: rightShoulderY,
    z: 0.0,
    visibility: visibility,
  );
  list[13] = NormalizedLandmark(
    x: leftElbowX,
    y: leftElbowY,
    z: 0.0,
    visibility: visibility,
  );
  list[14] = NormalizedLandmark(
    x: rightElbowX,
    y: rightElbowY,
    z: 0.0,
    visibility: visibility,
  );
  list[15] = NormalizedLandmark(
    x: 0.48,
    y: 0.55,
    z: 0.0,
    visibility: visibility,
  );
  list[16] = NormalizedLandmark(
    x: 0.52,
    y: 0.55,
    z: 0.0,
    visibility: visibility,
  );
  return PoseFrame(poseLandmarks: list);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockPoseFrameSource source;

  setUp(() {
    source = MockPoseFrameSource();
    when(() => source.start()).thenAnswer((_) async {});
    when(() => source.stop()).thenAnswer((_) async {});
    when(() => source.dispose()).thenAnswer((_) async {});
  });

  group('PostureBloc [HU-06]', () {
    blocTest<PostureBloc, PostureState>(
      'evalúa una postura ideal como ergonómica (score >= 90) por fotograma',
      build: () {
        when(
          () => source.poseFrameStream,
        ).thenAnswer((_) => Stream.fromIterable([buildFrame()]));
        return PostureBloc(frameSource: source);
      },
      act: (bloc) =>
          bloc.add(const StartPostureMonitoringEvent(InstrumentType.quena)),
      wait: const Duration(milliseconds: 100),
      expect: () => [
        isA<PostureAlignmentEvaluated>()
            .having((s) => s.isTracking, 'isTracking', isTrue)
            .having((s) => s.isErgonomic, 'isErgonomic', isTrue)
            .having(
              (s) => s.postureScorePercentage,
              'score',
              greaterThanOrEqualTo(90.0),
            )
            .having((s) => s.framesProcessed, 'framesProcessed', 1),
      ],
      verify: (_) => verify(() => source.start()).called(1),
    );

    blocTest<PostureBloc, PostureState>(
      'penaliza hombros desnivelados y marca la postura como no ergonómica',
      build: () {
        when(() => source.poseFrameStream).thenAnswer(
          (_) => Stream.fromIterable([
            buildFrame(leftShoulderY: 0.35, rightShoulderY: 0.45),
          ]),
        );
        return PostureBloc(frameSource: source);
      },
      act: (bloc) =>
          bloc.add(const StartPostureMonitoringEvent(InstrumentType.quena)),
      wait: const Duration(milliseconds: 100),
      expect: () => [
        isA<PostureAlignmentEvaluated>()
            .having((s) => s.isErgonomic, 'isErgonomic', isFalse)
            .having((s) => s.postureScorePercentage, 'score', lessThan(80.0))
            .having(
              (s) => s.feedback.any((m) => m.contains('Hombros desnivelados')),
              'warns about shoulders',
              isTrue,
            ),
      ],
    );

    blocTest<PostureBloc, PostureState>(
      'reporta pérdida de tracking cuando la confianza es baja (<0.5)',
      build: () {
        when(
          () => source.poseFrameStream,
        ).thenAnswer((_) => Stream.fromIterable([buildFrame(visibility: 0.2)]));
        return PostureBloc(frameSource: source);
      },
      act: (bloc) =>
          bloc.add(const StartPostureMonitoringEvent(InstrumentType.quena)),
      wait: const Duration(milliseconds: 100),
      expect: () => [
        isA<PostureAlignmentEvaluated>()
            .having((s) => s.isTracking, 'isTracking', isFalse)
            .having((s) => s.postureScorePercentage, 'score', 0.0),
      ],
    );

    blocTest<PostureBloc, PostureState>(
      'procesa una ráfaga de 30 fotogramas de forma determinista (soporta ≥24 FPS)',
      build: () {
        final frames = List.generate(30, (i) {
          final jitter = (i % 5) * 0.001;
          return buildFrame(
            leftShoulderY: 0.40 + jitter,
            rightShoulderY: 0.40 - jitter,
          );
        });
        when(
          () => source.poseFrameStream,
        ).thenAnswer((_) => Stream.fromIterable(frames));
        return PostureBloc(frameSource: source);
      },
      act: (bloc) =>
          bloc.add(const StartPostureMonitoringEvent(InstrumentType.quena)),
      wait: const Duration(milliseconds: 200),
      verify: (bloc) {
        final state = bloc.state;
        expect(state, isA<PostureAlignmentEvaluated>());
        expect((state as PostureAlignmentEvaluated).framesProcessed, 30);
        expect(state.isTracking, isTrue);
      },
    );

    blocTest<PostureBloc, PostureState>(
      'emite PostureCameraPermissionDenied si se deniega el permiso de cámara',
      build: () {
        when(
          () => source.poseFrameStream,
        ).thenAnswer((_) => const Stream<PoseFrame>.empty());
        when(
          () => source.start(),
        ).thenThrow(const CameraPermissionDeniedException());
        return PostureBloc(frameSource: source);
      },
      act: (bloc) =>
          bloc.add(const StartPostureMonitoringEvent(InstrumentType.tarka)),
      wait: const Duration(milliseconds: 50),
      expect: () => [isA<PostureCameraPermissionDenied>()],
    );

    blocTest<PostureBloc, PostureState>(
      'emite PostureError si el motor de pose falla al iniciar',
      build: () {
        when(
          () => source.poseFrameStream,
        ).thenAnswer((_) => const Stream<PoseFrame>.empty());
        when(
          () => source.start(),
        ).thenThrow(const PoseTrackingException('motor no disponible'));
        return PostureBloc(frameSource: source);
      },
      act: (bloc) =>
          bloc.add(const StartPostureMonitoringEvent(InstrumentType.zampona)),
      wait: const Duration(milliseconds: 50),
      expect: () => [
        isA<PostureError>().having(
          (s) => s.message,
          'message',
          'motor no disponible',
        ),
      ],
    );

    blocTest<PostureBloc, PostureState>(
      'al detener vuelve al estado inicial y libera la cámara',
      build: () {
        when(
          () => source.poseFrameStream,
        ).thenAnswer((_) => const Stream<PoseFrame>.empty());
        return PostureBloc(frameSource: source);
      },
      act: (bloc) async {
        bloc.add(const StartPostureMonitoringEvent(InstrumentType.quena));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(const StopPostureMonitoringEvent());
      },
      wait: const Duration(milliseconds: 50),
      expect: () => [const PostureInitial()],
      verify: (_) =>
          verify(() => source.stop()).called(greaterThanOrEqualTo(1)),
    );
  });
}
