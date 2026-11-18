import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/lesson_model.dart';
import '../../../data/models/note_sequence_model.dart';
import '../../../data/models/practice_session_model.dart';
import '../../../data/repositories/lesson_repository.dart';
import '../../../data/repositories/practice_repository.dart';
import 'practice_event.dart';
import 'practice_state.dart';

/// BLoC para gestionar la sesión de práctica.
class PracticeBloc extends Bloc<PracticeEvent, PracticeState> {
  final PracticeRepository _practiceRepository;
  final LessonRepository _lessonRepository;

  String _lessonId = '';
  LessonModel? _lesson;
  List<NoteSequenceModel> _allNotes = [];
  List<NoteSequenceModel> _notes = [];
  String? _handFilter; // null = ambas, 'left', 'right'
  bool _handAvailable = false;
  // Loop de sección (A-B): índices en _notes.
  bool _loopOn = false;
  int _loopStart = 0;
  int _loopEnd = 0;
  int _currentPos = 0;
  int _correctCount = 0;
  int _wrongCount = 0;
  // Notas acertadas SIN ningún error previo (precisión de primer intento). Es
  // la base del score real: como solo se avanza al acertar, _correctCount
  // siempre termina == total (daría 100% siempre). _firstTryCount sí distingue
  // qué tan bien tocaste.
  int _firstTryCount = 0;
  bool _missedCurrent = false; // hubo al menos un error en la nota actual
  final List<Map<String, dynamic>> _errors = [];

  /// Score = precisión de primer intento (notas clavadas sin error / total).
  double _score(int totalNotes) => totalNotes > 0
      ? ((_firstTryCount / totalNotes) * 100.0).clamp(0.0, 100.0)
      : 0.0;
  final Stopwatch _stopwatch = Stopwatch();

  PracticeBloc({
    required PracticeRepository practiceRepository,
    required LessonRepository lessonRepository,
  }) : _practiceRepository = practiceRepository,
       _lessonRepository = lessonRepository,
       super(const PracticeInitial()) {
    on<PracticeStart>(_onStart);
    on<PracticeNoteCorrect>(_onNoteCorrect);
    on<PracticeNoteWrong>(_onNoteWrong);
    on<PracticePause>(_onPause);
    on<PracticeResume>(_onResume);
    on<PracticeRetry>(_onRetry);
    on<PracticeRestart>(_onRestart);
    on<PracticeSetHand>(_onSetHand);
    on<PracticeSetLoop>(_onSetLoop);
    on<PracticeComplete>(_onComplete);
    on<PracticeSubmitResult>(_onSubmitResult);
  }

  /// En intermedio/avanzado la octava importa (estricta); en principiante es
  /// tolerante (cualquier octava de la nota cuenta).
  bool get _octaveStrict =>
      (_lesson?.difficulty ?? 'principiante').toLowerCase() != 'principiante';

  Future<void> _onStart(
    PracticeStart event,
    Emitter<PracticeState> emit,
  ) async {
    try {
      _lessonId = event.lessonId;
      _allNotes = event.expectedNotes;
      _handFilter = null;
      // Filtro de manos disponible solo si AMBAS manos tienen al menos una nota
      // tocable (no-silencio); si no, el selector no tendría sentido.
      _handAvailable =
          _allNotes.any((n) => n.hand == 'left' && !n.isRest) &&
          _allNotes.any((n) => n.hand == 'right' && !n.isRest);
      _notes = _filteredNotes();
      _currentPos = 0;
      _correctCount = 0;
      _wrongCount = 0;
      _firstTryCount = 0;
      _missedCurrent = false;
      _errors.clear();

      // Cargar datos de la lección
      final data = await _lessonRepository.getLessonDetail(event.lessonId);
      _lesson = data['lesson'] as LessonModel;

      // Filtrar silencios para la secuencia de notas tocables
      final playableNotes = _notes.where((n) => !n.isRest).toList();
      if (playableNotes.isEmpty) {
        emit(const PracticeError('La lección no tiene notas para practicar'));
        return;
      }

      _stopwatch.reset();
      _stopwatch.start();

      emit(
        PracticePlaying(
          currentPosition: _currentPos,
          correctCount: 0,
          wrongCount: 0,
          currentExpectedNote: _notes[_currentPos].note,
          elapsedSeconds: 0,
          notes: _notes,
          octaveStrict: _octaveStrict,
          handFilter: _handFilter,
          handFilterAvailable: _handAvailable,
        ),
      );
    } catch (e) {
      emit(PracticeError(e.toString()));
    }
  }

  /// Notas según el filtro de manos activo (null = todas).
  List<NoteSequenceModel> _filteredNotes() {
    if (_handFilter == null) return _allNotes;
    return _allNotes.where((n) => n.hand == _handFilter).toList();
  }

  /// Cambia el filtro de manos y reinicia la práctica con esas notas. Calcula
  /// el candidato ANTES de mutar el estado: si la mano no tiene notas tocables,
  /// ignora el cambio (sin desincronizar la UI).
  void _onSetHand(PracticeSetHand event, Emitter<PracticeState> emit) {
    final candidate = event.hand == null
        ? _allNotes
        : _allNotes.where((n) => n.hand == event.hand).toList();
    var pos = 0;
    while (pos < candidate.length && candidate[pos].isRest) {
      pos++;
    }
    if (pos >= candidate.length) return; // sin notas tocables: no cambiar nada
    _handFilter = event.hand;
    _notes = candidate;
    _currentPos = pos;
    _correctCount = 0;
    _wrongCount = 0;
    _firstTryCount = 0;
    _missedCurrent = false;
    _errors.clear();
    // El rango del loop ya no aplica a la nueva secuencia: se apaga y resetea.
    _loopOn = false;
    _loopStart = 0;
    _loopEnd = 0;
    _stopwatch.reset();
    _stopwatch.start();
    emit(
      PracticePlaying(
        currentPosition: _currentPos,
        correctCount: 0,
        wrongCount: 0,
        currentExpectedNote: _notes[_currentPos].note,
        elapsedSeconds: 0,
        notes: _notes,
        octaveStrict: _octaveStrict,
        handFilter: _handFilter,
        handFilterAvailable: _handAvailable,
      ),
    );
  }

  void _onNoteCorrect(PracticeNoteCorrect event, Emitter<PracticeState> emit) {
    _correctCount++;
    // Si la acertó sin haber fallado antes en esta nota, cuenta como "primer
    // intento" (lo que define el score). Luego se resetea para la próxima nota.
    if (!_missedCurrent) _firstTryCount++;
    _missedCurrent = false;
    _currentPos++;

    // Saltar silencios
    while (_currentPos < _notes.length && _notes[_currentPos].isRest) {
      _currentPos++;
    }

    // Loop de sección: al pasar el final del rango, volver al inicio (no
    // completa la lección hasta que el usuario apague el loop). Como los
    // límites se ajustan a bordes de acorde en _onSetLoop, el wrap cae en un
    // límite musical (no parte un acorde).
    if (_loopOn && _currentPos > _loopEnd) {
      _currentPos = _loopStart;
      while (_currentPos < _notes.length && _notes[_currentPos].isRest) {
        _currentPos++;
      }
      if (_currentPos > _loopEnd) {
        _loopOn = false; // defensivo: el rango quedó sin notas tocables
      }
    }

    if (_currentPos >= _notes.length) {
      _stopwatch.stop();
      final totalNotes = _notes.where((n) => !n.isRest).length;
      final score = _score(totalNotes);

      emit(
        PracticeCompleted(
          score: score,
          correctNotes: _firstTryCount,
          totalNotes: totalNotes,
          wrongNotes: _wrongCount,
          averageTempo: _lesson?.tempoBpm.toDouble() ?? 0,
          elapsedSeconds: _stopwatch.elapsedMilliseconds / 1000.0,
          errorsDetail: List<Map<String, dynamic>>.from(_errors),
        ),
      );
      return;
    }

    emit(
      PracticePlaying(
        currentPosition: _currentPos,
        correctCount: _correctCount,
        wrongCount: _wrongCount,
        currentExpectedNote: _notes[_currentPos].note,
        elapsedSeconds: _stopwatch.elapsedMilliseconds / 1000.0,
        notes: _notes,
        octaveStrict: _octaveStrict,
        handFilter: _handFilter,
        handFilterAvailable: _handAvailable,
      ),
    );
  }

  void _onNoteWrong(PracticeNoteWrong event, Emitter<PracticeState> emit) {
    _wrongCount++;
    _missedCurrent = true; // la nota actual ya no cuenta como primer intento
    _errors.add({
      'position': event.position,
      'expected': event.expected,
      'played': event.played,
      'timestamp': _stopwatch.elapsedMilliseconds / 1000.0,
    });

    // NO se pausa: se queda en la MISMA nota y sigue escuchando. La UI muestra
    // un aviso transitorio del error (la tecla mal en rojo) que se desvanece
    // solo, sin obligar al usuario a sacar las manos del instrumento para tocar un botón.
    if (_currentPos >= _notes.length) return;
    emit(
      PracticePlaying(
        currentPosition: _currentPos,
        correctCount: _correctCount,
        wrongCount: _wrongCount,
        currentExpectedNote: _notes[_currentPos].note,
        elapsedSeconds: _stopwatch.elapsedMilliseconds / 1000.0,
        notes: _notes,
        lastWrongPlayed: event.played,
        lastWrongExpected: event.expected,
        octaveStrict: _octaveStrict,
        handFilter: _handFilter,
        handFilterAvailable: _handAvailable,
      ),
    );
  }

  void _onPause(PracticePause event, Emitter<PracticeState> emit) {
    _stopwatch.stop();
    emit(
      PracticePaused(
        currentPosition: _currentPos,
        correctCount: _correctCount,
        wrongCount: _wrongCount,
        notes: _notes,
        elapsedSeconds: _stopwatch.elapsedMilliseconds / 1000.0,
      ),
    );
  }

  /// Reinicia la lección desde la primera nota: resetea progreso, errores y
  /// cronómetro. Reutiliza las notas ya cargadas (no recarga la lección).
  void _onRestart(PracticeRestart event, Emitter<PracticeState> emit) {
    if (_notes.isEmpty) return;
    _currentPos = 0;
    _correctCount = 0;
    _wrongCount = 0;
    _firstTryCount = 0;
    _missedCurrent = false;
    _errors.clear();
    // Saltar silencios iniciales para arrancar en la primera nota tocable.
    while (_currentPos < _notes.length && _notes[_currentPos].isRest) {
      _currentPos++;
    }
    if (_currentPos >= _notes.length) return; // sin notas tocables
    _stopwatch.reset();
    _stopwatch.start();
    emit(
      PracticePlaying(
        currentPosition: _currentPos,
        correctCount: 0,
        wrongCount: 0,
        currentExpectedNote: _notes[_currentPos].note,
        elapsedSeconds: 0,
        notes: _notes,
        octaveStrict: _octaveStrict,
        handFilter: _handFilter,
        handFilterAvailable: _handAvailable,
      ),
    );
  }

  void _onResume(PracticeResume event, Emitter<PracticeState> emit) {
    _stopwatch.start();

    // Avanzar a siguiente nota si estaba pausado por error
    if (_currentPos < _notes.length) {
      _currentPos++;
      // Saltar silencios
      while (_currentPos < _notes.length && _notes[_currentPos].isRest) {
        _currentPos++;
      }
    }

    if (_currentPos >= _notes.length) {
      _stopwatch.stop();
      final totalNotes = _notes.where((n) => !n.isRest).length;
      final score = _score(totalNotes);

      emit(
        PracticeCompleted(
          score: score,
          correctNotes: _firstTryCount,
          totalNotes: totalNotes,
          wrongNotes: _wrongCount,
          averageTempo: _lesson?.tempoBpm.toDouble() ?? 0,
          elapsedSeconds: _stopwatch.elapsedMilliseconds / 1000.0,
          errorsDetail: List<Map<String, dynamic>>.from(_errors),
        ),
      );
      return;
    }

    emit(
      PracticePlaying(
        currentPosition: _currentPos,
        correctCount: _correctCount,
        wrongCount: _wrongCount,
        currentExpectedNote: _notes[_currentPos].note,
        elapsedSeconds: _stopwatch.elapsedMilliseconds / 1000.0,
        notes: _notes,
        octaveStrict: _octaveStrict,
        handFilter: _handFilter,
        handFilterAvailable: _handAvailable,
      ),
    );
  }

  /// Reintenta la MISMA nota: reanuda sin avanzar la posición. Así, ante un
  /// error, el usuario repite la nota hasta acertar (no se saltea).
  void _onRetry(PracticeRetry event, Emitter<PracticeState> emit) {
    if (_currentPos >= _notes.length) return;
    _stopwatch.start();
    emit(
      PracticePlaying(
        currentPosition: _currentPos,
        correctCount: _correctCount,
        wrongCount: _wrongCount,
        currentExpectedNote: _notes[_currentPos].note,
        elapsedSeconds: _stopwatch.elapsedMilliseconds / 1000.0,
        notes: _notes,
        octaveStrict: _octaveStrict,
        handFilter: _handFilter,
        handFilterAvailable: _handAvailable,
      ),
    );
  }

  /// Primer/último índice del grupo de acorde de [i] (para no partir un acorde
  /// con los límites del loop).
  int _chordStart(int i) {
    final g = _notes[i].chordGroup;
    if (g == null) return i;
    while (i > 0 && _notes[i - 1].chordGroup == g) {
      i--;
    }
    return i;
  }

  int _chordEnd(int i) {
    final g = _notes[i].chordGroup;
    if (g == null) return i;
    while (i < _notes.length - 1 && _notes[i + 1].chordGroup == g) {
      i++;
    }
    return i;
  }

  /// Configura el loop de sección. Ajusta los límites a bordes de acorde y
  /// valida que el rango tenga al menos una nota tocable; si no, lo desactiva.
  void _onSetLoop(PracticeSetLoop event, Emitter<PracticeState> emit) {
    if (_notes.isEmpty) return;
    final maxIdx = _notes.length - 1;
    final start = _chordStart(event.start.clamp(0, maxIdx));
    final end = _chordEnd(event.end.clamp(start, maxIdx));
    final hasPlayable = _notes.sublist(start, end + 1).any((n) => !n.isRest);
    if (!event.enabled || !hasPlayable) {
      _loopOn = false;
      return;
    }
    _loopOn = true;
    _loopStart = start;
    _loopEnd = end;
    if (_currentPos < _loopStart || _currentPos > _loopEnd) {
      _currentPos = _loopStart;
      while (_currentPos < _notes.length && _notes[_currentPos].isRest) {
        _currentPos++;
      }
      if (_currentPos > _loopEnd) {
        _loopOn = false; // defensivo: rango sin notas tocables
        return;
      }
      emit(
        PracticePlaying(
          currentPosition: _currentPos,
          correctCount: _correctCount,
          wrongCount: _wrongCount,
          currentExpectedNote: _notes[_currentPos].note,
          elapsedSeconds: _stopwatch.elapsedMilliseconds / 1000.0,
          notes: _notes,
          octaveStrict: _octaveStrict,
          handFilter: _handFilter,
          handFilterAvailable: _handAvailable,
        ),
      );
    }
  }

  void _onComplete(PracticeComplete event, Emitter<PracticeState> emit) {
    _stopwatch.stop();
    final totalNotes = _notes.where((n) => !n.isRest).length;
    final score = totalNotes > 0
        ? ((_correctCount / totalNotes) * 100.0).clamp(0.0, 100.0)
        : 0.0;

    emit(
      PracticeCompleted(
        score: score,
        correctNotes: _correctCount,
        totalNotes: totalNotes,
        wrongNotes: _wrongCount,
        averageTempo: _lesson?.tempoBpm.toDouble() ?? 0,
        elapsedSeconds: _stopwatch.elapsedMilliseconds / 1000.0,
        errorsDetail: List<Map<String, dynamic>>.from(_errors),
      ),
    );
  }

  Future<void> _onSubmitResult(
    PracticeSubmitResult event,
    Emitter<PracticeState> emit,
  ) async {
    try {
      final totalNotes = _notes.where((n) => !n.isRest).length;
      final result = await _practiceRepository.submitPractice(
        lessonId: _lessonId,
        score: event.score,
        correctNotes: event.correctNotes,
        totalNotes: totalNotes,
        wrongNotes: event.wrongNotes,
        missedNotes: event.missedNotes,
        averageTempo: event.averageTempo,
        totalTimeSeconds: event.totalTimeSeconds,
        errorsDetail: event.errorsDetail,
      );

      emit(
        PracticeResultSubmitted(
          session: result['session'] as PracticeSessionModel,
          aiFeedback: result['ai_feedback'] as String?,
        ),
      );
    } catch (e) {
      emit(PracticeError(e.toString()));
    }
  }
}
