import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:mobile/core/audio/instrument.dart';
import 'package:mobile/features/practice/posture/mediapipe_pose_service.dart';
import 'package:mobile/features/practice/posture/mediapipe_posture_pipeline.dart';
import 'package:mobile/features/practice/posture/pose_frame_source.dart';
import 'package:mobile/features/practice/posture/posture_scorer.dart';

// ── Eventos ───────────────────────────────────────────────────────────────

abstract class PostureEvent extends Equatable {
  const PostureEvent();

  @override
  List<Object?> get props => const [];
}

/// Inicia el monitoreo postural en tiempo real para el [instrument] activo.
class StartPostureMonitoringEvent extends PostureEvent {
  final InstrumentType instrument;
  const StartPostureMonitoringEvent(this.instrument);

  @override
  List<Object?> get props => [instrument];
}

/// Detiene el monitoreo postural y libera la cámara.
class StopPostureMonitoringEvent extends PostureEvent {
  const StopPostureMonitoringEvent();
}

/// Evento interno: nuevo fotograma de pose proveniente de [PoseFrameSource].
class _PoseFrameCaptured extends PostureEvent {
  final PoseFrame frame;
  const _PoseFrameCaptured(this.frame);

  @override
  List<Object?> get props => [frame];
}

/// Evento interno: error propagado por el stream de la fuente de pose.
class _PoseStreamErrored extends PostureEvent {
  final Object error;
  const _PoseStreamErrored(this.error);

  @override
  List<Object?> get props => [error];
}

// ── Estados ───────────────────────────────────────────────────────────────

abstract class PostureState extends Equatable {
  const PostureState();

  @override
  List<Object?> get props => const [];
}

class PostureInitial extends PostureState {
  const PostureInitial();
}

/// Resultado de evaluar la alineación anatómica de un fotograma
/// (`CameraFrame -> AlignmentEvaluated`, según el C4 del proyecto).
///
/// Transporta la [PostureEvaluation] íntegra (puntuación 0–100, ángulos,
/// estado de tracking y retroalimentación ergonómica) y el conteo
/// determinista de fotogramas procesados.
class PostureAlignmentEvaluated extends PostureState {
  final PostureEvaluation evaluation;
  final int framesProcessed;

  const PostureAlignmentEvaluated({
    required this.evaluation,
    required this.framesProcessed,
  });

  /// Puntuación de postura 0–100 (`posture_score_percentage`).
  double get postureScorePercentage => evaluation.overallScore;

  bool get isErgonomic => evaluation.isErgonomic;

  /// `true` mientras la cámara mantiene visibilidad del músico (confianza ≥0.5).
  bool get isTracking => evaluation.status == PostureTrackingStatus.tracking;

  List<String> get feedback => evaluation.feedback;

  @override
  List<Object?> get props => [
    evaluation.overallScore,
    evaluation.isErgonomic,
    evaluation.status,
    evaluation.shoulderTiltDegrees,
    evaluation.neckTiltDegrees,
    evaluation.leftElbowDegrees,
    evaluation.rightElbowDegrees,
    evaluation.feedback,
    framesProcessed,
  ];
}

/// El permiso de cámara frontal fue denegado.
class PostureCameraPermissionDenied extends PostureState {
  final String message;
  const PostureCameraPermissionDenied([
    this.message = 'Se requiere permiso de cámara para evaluar tu postura.',
  ]);

  @override
  List<Object?> get props => [message];
}

/// Fallo irrecuperable al iniciar o sostener el seguimiento postural.
class PostureError extends PostureState {
  final String message;
  const PostureError(this.message);

  @override
  List<Object?> get props => [message];
}

// ── Bloc ──────────────────────────────────────────────────────────────────

/// [SUB-06-A/B] Monitoreo postural en tiempo real con MediaPipe Pose.
///
/// Suscribe los fotogramas de [PoseFrameSource] (cámara frontal + inferencia
/// on-device) y delega la evaluación anatómica —verticalidad de cuello,
/// nivelación de hombros y apertura de codos— a [MediaPipePosturePipeline],
/// emitiendo un [PostureAlignmentEvaluated] por fotograma con la puntuación
/// 0–100 y las alertas ergonómicas. La temporización se basa en el conteo de
/// fotogramas (determinista y comprobable; sin timers reales).
///
/// Inferencia 100% on-device: ni audio ni video crudo salen del dispositivo.
class PostureBloc extends Bloc<PostureEvent, PostureState> {
  final PoseFrameSource _frameSource;
  final MediaPipePosturePipeline _pipeline;

  StreamSubscription<PoseFrame>? _subscription;
  InstrumentType _instrument = InstrumentType.quena;
  int _framesProcessed = 0;

  PostureBloc({
    PoseFrameSource? frameSource,
    MediaPipePosturePipeline? pipeline,
  }) : _frameSource = frameSource ?? MediaPipePoseService(),
       _pipeline = pipeline ?? const MediaPipePosturePipeline(),
       super(const PostureInitial()) {
    on<StartPostureMonitoringEvent>(_onStart);
    on<_PoseFrameCaptured>(_onFrame);
    on<_PoseStreamErrored>(_onStreamError);
    on<StopPostureMonitoringEvent>(_onStop);
  }

  Future<void> _teardown() async {
    await _subscription?.cancel();
    _subscription = null;
    await _frameSource.stop();
  }

  Future<void> _onStart(
    StartPostureMonitoringEvent event,
    Emitter<PostureState> emit,
  ) async {
    _instrument = event.instrument;
    _framesProcessed = 0;
    try {
      await _frameSource.start();
      await _subscription?.cancel();
      _subscription = _frameSource.poseFrameStream.listen(
        (frame) => add(_PoseFrameCaptured(frame)),
        onError: (Object error) => add(_PoseStreamErrored(error)),
      );
    } on CameraPermissionDeniedException catch (e) {
      emit(PostureCameraPermissionDenied(e.message));
    } on PoseTrackingException catch (e) {
      emit(PostureError(e.message));
    } catch (_) {
      emit(const PostureError('No se pudo iniciar la cámara postural.'));
    }
  }

  void _onFrame(_PoseFrameCaptured event, Emitter<PostureState> emit) {
    if (state is PostureError || state is PostureCameraPermissionDenied) {
      return;
    }

    final evaluation = _pipeline.evaluatePoseAndHands(
      poseLandmarks: event.frame.poseLandmarks,
      leftHandLandmarks: event.frame.leftHandLandmarks,
      rightHandLandmarks: event.frame.rightHandLandmarks,
      instrument: _instrument,
    );
    _framesProcessed++;

    emit(
      PostureAlignmentEvaluated(
        evaluation: evaluation,
        framesProcessed: _framesProcessed,
      ),
    );
  }

  Future<void> _onStreamError(
    _PoseStreamErrored event,
    Emitter<PostureState> emit,
  ) async {
    await _teardown();
    final error = event.error;
    if (error is CameraPermissionDeniedException) {
      emit(PostureCameraPermissionDenied(error.message));
    } else {
      emit(
        PostureError(
          error is PoseTrackingException
              ? error.message
              : 'Se perdió el seguimiento postural.',
        ),
      );
    }
  }

  Future<void> _onStop(
    StopPostureMonitoringEvent event,
    Emitter<PostureState> emit,
  ) async {
    await _teardown();
    _framesProcessed = 0;
    emit(const PostureInitial());
  }

  @override
  Future<void> close() async {
    await _teardown();
    return super.close();
  }
}
