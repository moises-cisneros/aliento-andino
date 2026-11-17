import 'dart:async';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:mobile/core/audio/audio_capture_service.dart';
import 'package:mobile/core/audio/breath_calibrator.dart';
import 'package:mobile/core/audio/instrument.dart';
import 'package:mobile/core/audio/yin_pitch_detector.dart';

// ── Eventos ───────────────────────────────────────────────────────────────

abstract class BreathCalibrationEvent extends Equatable {
  const BreathCalibrationEvent();

  @override
  List<Object?> get props => const [];
}

/// Inicia la calibración de "Soplo Suave" para el [instrument] activo.
class StartBreathCalibrationEvent extends BreathCalibrationEvent {
  final InstrumentType instrument;
  const StartBreathCalibrationEvent(this.instrument);

  @override
  List<Object?> get props => [instrument];
}

/// Cancela una calibración en curso.
class CancelBreathCalibrationEvent extends BreathCalibrationEvent {
  const CancelBreathCalibrationEvent();
}

/// Evento interno: nueva lectura de energía RMS proveniente del micrófono.
class _BreathSampleReceived extends BreathCalibrationEvent {
  final double rmsEnergy;
  const _BreathSampleReceived(this.rmsEnergy);

  @override
  List<Object?> get props => [rmsEnergy];
}

// ── Estados ───────────────────────────────────────────────────────────────

abstract class BreathCalibrationState extends Equatable {
  const BreathCalibrationState();

  @override
  List<Object?> get props => const [];
}

class BreathCalibrationInitial extends BreathCalibrationState {
  const BreathCalibrationInitial();
}

/// Progreso del soplo: segundos transcurridos y energía RMS instantánea.
class BreathCalibrationProgress extends BreathCalibrationState {
  final double secondsElapsed;
  final double currentRmsEnergy;
  const BreathCalibrationProgress({
    required this.secondsElapsed,
    required this.currentRmsEnergy,
  });

  @override
  List<Object?> get props => [secondsElapsed, currentRmsEnergy];
}

/// Calibración completada con el umbral basal calculado.
class BreathCalibrationCompleted extends BreathCalibrationState {
  final double baselineRmsThreshold;
  const BreathCalibrationCompleted(this.baselineRmsThreshold);

  @override
  List<Object?> get props => [baselineRmsThreshold];
}

/// Calibración fallida (soplo interrumpido, muestras insuficientes, etc.).
class BreathCalibrationFailed extends BreathCalibrationState {
  final String message;
  const BreathCalibrationFailed(this.message);

  @override
  List<Object?> get props => [message];
}

class BreathCalibrationPermissionDenied extends BreathCalibrationState {
  final String message;
  const BreathCalibrationPermissionDenied([
    this.message = 'Se requiere permiso de micrófono para calibrar el soplo.',
  ]);

  @override
  List<Object?> get props => [message];
}

// ── Bloc ──────────────────────────────────────────────────────────────────

/// [SUB-02-A] Asistente guiado de medición acústica basal (3 segundos).
///
/// Captura energía RMS mientras el estudiante emite un soplo continuo; al
/// completar la ventana de [requiredSeconds] delega el cálculo del umbral a
/// [BreathCalibrator] y lo persiste. La temporización se basa en la cantidad de
/// muestras capturadas (determinista y testeable).
class BreathCalibrationBloc
    extends Bloc<BreathCalibrationEvent, BreathCalibrationState> {
  final AudioCaptureService _capture;
  final YinPitchDetector _detector;
  final BreathCalibrator _calibrator;

  /// Frecuencia de muestreo usada para traducir muestras → segundos.
  final int sampleRate;

  /// Duración objetivo del soplo continuo.
  final double requiredSeconds;

  /// Energía RMS mínima para considerar que el soplo comenzó.
  final double onsetThreshold;

  StreamSubscription<Float32List>? _subscription;
  final List<double> _rmsSamples = [];
  int _blowSampleCount = 0;
  bool _blowStarted = false;

  BreathCalibrationBloc({
    AudioCaptureService? captureService,
    YinPitchDetector? pitchDetector,
    BreathCalibrator? calibrator,
    this.sampleRate = 44100,
    this.requiredSeconds = 3.0,
    this.onsetThreshold = 0.01,
  }) : _capture = captureService ?? AudioCaptureService(),
       _detector = pitchDetector ?? const YinPitchDetector(),
       _calibrator = calibrator ?? const BreathCalibrator(),
       super(const BreathCalibrationInitial()) {
    on<StartBreathCalibrationEvent>(_onStart);
    on<_BreathSampleReceived>(_onSample);
    on<CancelBreathCalibrationEvent>(_onCancel);
  }

  void _reset() {
    _rmsSamples.clear();
    _blowSampleCount = 0;
    _blowStarted = false;
  }

  Future<void> _finishCapture() async {
    await _subscription?.cancel();
    _subscription = null;
    await _capture.stopCapture();
  }

  Future<void> _onStart(
    StartBreathCalibrationEvent event,
    Emitter<BreathCalibrationState> emit,
  ) async {
    _reset();
    emit(
      const BreathCalibrationProgress(secondsElapsed: 0, currentRmsEnergy: 0),
    );
    try {
      await _capture.startCapture();
      await _subscription?.cancel();
      _subscription = _capture.pcmAudioStream.listen((chunk) {
        final rms = _detector.calculateRms(chunk);
        if (_blowStarted || rms >= onsetThreshold) {
          _blowSampleCount += chunk.length;
        }
        add(_BreathSampleReceived(rms));
      });
    } on PermissionDeniedException {
      emit(const BreathCalibrationPermissionDenied());
    } catch (_) {
      emit(
        const BreathCalibrationFailed(
          'No se pudo iniciar la captura de audio.',
        ),
      );
    }
  }

  Future<void> _onSample(
    _BreathSampleReceived event,
    Emitter<BreathCalibrationState> emit,
  ) async {
    if (state is BreathCalibrationCompleted ||
        state is BreathCalibrationFailed ||
        state is BreathCalibrationPermissionDenied) {
      return;
    }

    final rms = event.rmsEnergy;
    if (rms >= onsetThreshold) _blowStarted = true;

    // Antes de que inicie el soplo, seguimos esperando.
    if (!_blowStarted) {
      emit(
        const BreathCalibrationProgress(secondsElapsed: 0, currentRmsEnergy: 0),
      );
      return;
    }

    // Soplo interrumpido tras haber comenzado.
    if (rms < BreathCalibrator.silenceFloor) {
      await _finishCapture();
      emit(
        const BreathCalibrationFailed(
          'Soplo interrumpido. Intenta mantener el flujo constante durante 3 segundos.',
        ),
      );
      return;
    }

    _rmsSamples.add(rms);
    final elapsed = _blowSampleCount / sampleRate;

    if (elapsed >= requiredSeconds) {
      await _finishCapture();
      try {
        final threshold = _calibrator.calculateThreshold(_rmsSamples);
        await _calibrator.saveThreshold(threshold);
        emit(BreathCalibrationCompleted(threshold));
      } on BreathCalibrationException catch (e) {
        emit(BreathCalibrationFailed(e.message));
      }
      return;
    }

    emit(
      BreathCalibrationProgress(secondsElapsed: elapsed, currentRmsEnergy: rms),
    );
  }

  Future<void> _onCancel(
    CancelBreathCalibrationEvent event,
    Emitter<BreathCalibrationState> emit,
  ) async {
    await _finishCapture();
    _reset();
    emit(const BreathCalibrationInitial());
  }

  @override
  Future<void> close() async {
    await _finishCapture();
    return super.close();
  }
}
