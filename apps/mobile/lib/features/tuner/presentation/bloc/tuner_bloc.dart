import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/audio/audio_capture_service.dart';
import 'package:mobile/core/audio/fingering_models.dart';
import 'package:mobile/core/audio/instrument.dart';
import 'package:mobile/core/audio/yin_pitch_detector.dart';

// ── Eventos ───────────────────────────────────────────────────────────────

abstract class TunerEvent {
  const TunerEvent();
}

class TunerStarted extends TunerEvent {
  final InstrumentType instrument;
  final double toleranceCents;

  const TunerStarted({
    this.instrument = InstrumentType.quena,
    this.toleranceCents = 15.0,
  });
}

class TunerStopped extends TunerEvent {
  const TunerStopped();
}

class TunerPitchSampleReceived extends TunerEvent {
  final double detectedHz;
  final String targetNote;
  final double targetHz;

  const TunerPitchSampleReceived({
    required this.detectedHz,
    required this.targetNote,
    required this.targetHz,
  });
}

class TunerToleranceChanged extends TunerEvent {
  final double toleranceCents;

  const TunerToleranceChanged(this.toleranceCents);
}

class TunerInstrumentChanged extends TunerEvent {
  final InstrumentType instrument;

  const TunerInstrumentChanged(this.instrument);
}

// ── Estados ───────────────────────────────────────────────────────────────

abstract class TunerState {
  const TunerState();
}

class TunerInitial extends TunerState {
  const TunerInitial();
}

class TunerPermissionDenied extends TunerState {
  final String message;
  const TunerPermissionDenied([
    this.message = 'Se requiere permiso de micrófono para afinar.',
  ]);
}

class TunerActiveState extends TunerState {
  final double centsDeviation;
  final String noteName;
  final bool isTuned;
  final double frequencyHz;
  final double targetFrequencyHz;
  final InstrumentType instrument;
  final double toleranceCents;
  final bool isSilent;

  const TunerActiveState({
    required this.centsDeviation,
    required this.noteName,
    required this.isTuned,
    required this.frequencyHz,
    required this.targetFrequencyHz,
    required this.instrument,
    required this.toleranceCents,
    this.isSilent = false,
  });

  TunerActiveState copyWith({
    double? centsDeviation,
    String? noteName,
    bool? isTuned,
    double? frequencyHz,
    double? targetFrequencyHz,
    InstrumentType? instrument,
    double? toleranceCents,
    bool? isSilent,
  }) {
    return TunerActiveState(
      centsDeviation: centsDeviation ?? this.centsDeviation,
      noteName: noteName ?? this.noteName,
      isTuned: isTuned ?? this.isTuned,
      frequencyHz: frequencyHz ?? this.frequencyHz,
      targetFrequencyHz: targetFrequencyHz ?? this.targetFrequencyHz,
      instrument: instrument ?? this.instrument,
      toleranceCents: toleranceCents ?? this.toleranceCents,
      isSilent: isSilent ?? this.isSilent,
    );
  }

  @override
  String toString() =>
      'TunerActiveState(note: $noteName, cents: ${centsDeviation.toStringAsFixed(1)}, tuned: $isTuned, silent: $isSilent)';
}

// ── Bloc ─────────────────────────────────────────────────────────────────

class TunerBloc extends Bloc<TunerEvent, TunerState> {
  final YinPitchDetector _pitchDetector;
  final AudioCaptureService _captureService;
  StreamSubscription? _audioSubscription;

  InstrumentType _currentInstrument = InstrumentType.quena;
  double _currentTolerance = 15.0;

  TunerBloc({
    YinPitchDetector? pitchDetector,
    AudioCaptureService? captureService,
  }) : _pitchDetector = pitchDetector ?? const YinPitchDetector(),
       _captureService = captureService ?? AudioCaptureService(),
       super(const TunerInitial()) {
    on<TunerStarted>(_onStarted);
    on<TunerStopped>(_onStopped);
    on<TunerPitchSampleReceived>(_onPitchSampleReceived);
    on<TunerToleranceChanged>(_onToleranceChanged);
    on<TunerInstrumentChanged>(_onInstrumentChanged);
  }

  Future<void> _onStarted(TunerStarted event, Emitter<TunerState> emit) async {
    _currentInstrument = event.instrument;
    _currentTolerance = event.toleranceCents;

    emit(
      TunerActiveState(
        centsDeviation: 0.0,
        noteName: '--',
        isTuned: false,
        frequencyHz: 0.0,
        targetFrequencyHz: 0.0,
        instrument: _currentInstrument,
        toleranceCents: _currentTolerance,
        isSilent: true,
      ),
    );

    try {
      await _captureService.startCapture();
      await _audioSubscription?.cancel();
      _audioSubscription = _captureService.pcmAudioStream.listen((samples) {
        final f0 = _pitchDetector.detectFundamentalFrequency(samples);
        if (f0 <= 0.0) {
          add(
            const TunerPitchSampleReceived(
              detectedHz: 0.0,
              targetNote: '--',
              targetHz: 0.0,
            ),
          );
        } else {
          final noteInfo = _closestAndeanNote(f0, _currentInstrument);
          add(
            TunerPitchSampleReceived(
              detectedHz: f0,
              targetNote: noteInfo.name,
              targetHz: noteInfo.frequency,
            ),
          );
        }
      });
    } on PermissionDeniedException {
      emit(const TunerPermissionDenied());
    } catch (e) {
      // Si falla hardware, silenciar
      emit(
        TunerActiveState(
          centsDeviation: 0.0,
          noteName: '--',
          isTuned: false,
          frequencyHz: 0.0,
          targetFrequencyHz: 0.0,
          instrument: _currentInstrument,
          toleranceCents: _currentTolerance,
          isSilent: true,
        ),
      );
    }
  }

  Future<void> _onStopped(TunerStopped event, Emitter<TunerState> emit) async {
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    await _captureService.stopCapture();
    emit(const TunerInitial());
  }

  void _onPitchSampleReceived(
    TunerPitchSampleReceived event,
    Emitter<TunerState> emit,
  ) {
    if (state is! TunerActiveState) return;
    final current = state as TunerActiveState;

    if (event.detectedHz <= 0.0 || event.targetHz <= 0.0) {
      // Silencio o nota inaudible: aguja gradualmente en reposo
      emit(current.copyWith(isSilent: true, frequencyHz: 0.0));
      return;
    }

    final eval = _pitchDetector.evaluateTuning(
      detectedHz: event.detectedHz,
      targetHz: event.targetHz,
      toleranceCents: current.toleranceCents,
    );

    emit(
      current.copyWith(
        centsDeviation: eval.centsDeviation.clamp(-50.0, 50.0),
        noteName: event.targetNote,
        isTuned: eval.isTuned,
        frequencyHz: event.detectedHz,
        targetFrequencyHz: event.targetHz,
        isSilent: false,
      ),
    );
  }

  void _onToleranceChanged(
    TunerToleranceChanged event,
    Emitter<TunerState> emit,
  ) {
    _currentTolerance = event.toleranceCents;
    if (state is TunerActiveState) {
      emit(
        (state as TunerActiveState).copyWith(
          toleranceCents: event.toleranceCents,
        ),
      );
    }
  }

  void _onInstrumentChanged(
    TunerInstrumentChanged event,
    Emitter<TunerState> emit,
  ) {
    _currentInstrument = event.instrument;
    _currentTolerance = event.instrument.defaultToleranceCents;
    if (state is TunerActiveState) {
      final current = state as TunerActiveState;
      if (current.frequencyHz > 0) {
        final noteInfo = _closestAndeanNote(
          current.frequencyHz,
          event.instrument,
        );
        final eval = _pitchDetector.evaluateTuning(
          detectedHz: current.frequencyHz,
          targetHz: noteInfo.frequency,
          toleranceCents: _currentTolerance,
        );
        emit(
          current.copyWith(
            instrument: event.instrument,
            toleranceCents: _currentTolerance,
            noteName: noteInfo.name,
            targetFrequencyHz: noteInfo.frequency,
            centsDeviation: eval.centsDeviation.clamp(-50.0, 50.0),
            isTuned: eval.isTuned,
          ),
        );
      } else {
        emit(
          current.copyWith(
            instrument: event.instrument,
            toleranceCents: _currentTolerance,
          ),
        );
      }
    }
  }

  @override
  Future<void> close() async {
    await _audioSubscription?.cancel();
    await _captureService.dispose();
    return super.close();
  }

  /// Convierte un número MIDI a su nombre en español con octava (ej. 67 -> 'Sol4').
  static String midiToSpanishNote(int midi) {
    const names = [
      'Do',
      'Do#',
      'Re',
      'Re#',
      'Mi',
      'Fa',
      'Fa#',
      'Sol',
      'Sol#',
      'La',
      'La#',
      'Si',
    ];
    final semitone = midi % 12;
    final octave = (midi ~/ 12) - 1;
    return '${names[semitone]}$octave';
  }

  /// Calcula la frecuencia en Hz para una nota MIDI en afinación estándar A440.
  static double midiToFrequency(int midi) {
    return 440.0 * math.pow(2.0, (midi - 69) / 12.0);
  }

  /// Notas andinas derivadas directamente de los modelos de digitación.
  static final Map<InstrumentType, List<(String, double)>> _instrumentNotes = {
    // Quena: Sol4 (MIDI 67) a Sol6 (MIDI 91). Rango cromático real, sin registro de quenacho.
    InstrumentType.quena: [
      for (
        int m = QuenaFingering.lowestMidi;
        m <= QuenaFingering.highestMidi;
        m++
      )
        (midiToSpanishNote(m), midiToFrequency(m)),
    ],
    // Zampoña Malta tradicional de 13 tubos: Fa#4 (MIDI 66) a Re6 (MIDI 86).
    InstrumentType.zampona: () {
      final set = <int>{};
      for (final n in [
        ...ZamponaFingering.arcaNotes,
        ...ZamponaFingering.iraNotes,
      ]) {
        final midi = parseNoteToMidi(n);
        if (midi != null) set.add(midi);
      }
      final sorted = set.toList()..sort();
      return sorted
          .map((m) => (midiToSpanishNote(m), midiToFrequency(m)))
          .toList();
    }(),
    // Tarka tradicional: Do5 (MIDI 72) a Re6 (MIDI 86) con sobretonos de tara.
    InstrumentType.tarka: const [
      72,
      74,
      76,
      77,
      79,
      81,
      83,
      84,
      86,
    ].map((m) => (midiToSpanishNote(m), midiToFrequency(m))).toList(),
  };

  /// Busca la nota andina más cercana a la frecuencia detectada según el instrumento,
  /// utilizando distancia logarítmica en cents: 1200 * |log2(f / f_target)|.
  static ({String name, double frequency}) _closestAndeanNote(
    double detectedHz,
    InstrumentType instrument,
  ) {
    final notes =
        _instrumentNotes[instrument] ?? _instrumentNotes[InstrumentType.quena]!;

    if (detectedHz <= 0.0) {
      return (name: notes.first.$1, frequency: notes.first.$2);
    }

    var bestNote = notes.first;
    var minCentsDiff =
        (1200.0 * (math.log(detectedHz / bestNote.$2) / math.ln2)).abs();

    for (final n in notes) {
      final centsDiff = (1200.0 * (math.log(detectedHz / n.$2) / math.ln2))
          .abs();
      if (centsDiff < minCentsDiff) {
        minCentsDiff = centsDiff;
        bestNote = n;
      }
    }

    return (name: bestNote.$1, frequency: bestNote.$2);
  }
}
