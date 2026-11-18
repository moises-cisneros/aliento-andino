import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:go_router/go_router.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/audio/instrument_service.dart';
import '../../../../core/audio/practice_recorder.dart';
import '../../../../core/audio/tone_synth.dart';
import '../../../../core/practice/practice_help_service.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../data/models/lesson_model.dart';
import '../../data/repositories/lesson_repository.dart';
import '../../data/repositories/practice_repository.dart';
import '../../data/services/midi_input_service.dart';
import '../bloc/practice/practice_bloc.dart';
import '../bloc/practice/practice_event.dart';
import '../bloc/practice/practice_state.dart';
import '../services/hand_tracker.dart';
import '../services/note_detector.dart';
import '../services/posture_analyzer.dart';
import '../widgets/falling_notes_view.dart';
import '../widgets/hand_tracker_camera.dart';
import '../widgets/midi_listener_widget.dart';
import '../widgets/note_listener_widget.dart';
import '../widgets/note_sequence_viewer.dart';
import '../../../instrument_select/presentation/widgets/instrument_selector_appbar.dart';
import '../widgets/practice_progress_bar.dart';
import '../widgets/practice_toolbar_help_sheet.dart';
import '../widgets/staff_view.dart';
import '../../../../core/theme/app_theme.dart';

/// Vistas alternativas del cuerpo de práctica (se ciclan con un botón).
enum _PlayView { sequence, cascade, staff }

/// Modo de evaluación de la práctica, derivado de qué entrada está activa:
/// manual (ninguna), micrófono, cámara, combinado (mic + cámara), o MIDI
/// (dispositivo/interfaz digital conectada, máxima precisión).
enum _InputMode { manual, mic, camera, combined, midi }

/// Pantalla de práctica a pantalla completa.
class PracticeScreen extends StatelessWidget {
  final String lessonId;

  const PracticeScreen({super.key, required this.lessonId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final bloc = PracticeBloc(
          practiceRepository: context.read<PracticeRepository>(),
          lessonRepository: context.read<LessonRepository>(),
        );
        // Cargar notas y empezar
        context.read<LessonRepository>().getLessonSequence(lessonId).then((
          notes,
        ) {
          bloc.add(PracticeStart(lessonId: lessonId, expectedNotes: notes));
        });
        return bloc;
      },
      child: _PracticeContent(lessonId: lessonId),
    );
  }
}

class _PracticeContent extends StatefulWidget {
  final String lessonId;
  const _PracticeContent({required this.lessonId});

  @override
  State<_PracticeContent> createState() => _PracticeContentState();
}

class _PracticeContentState extends State<_PracticeContent> {
  bool _handTrackerEnabled = false;
  bool _micEnabled = false;
  HandTracker? _sharedTracker;

  /// Detector de notas activo (lo crea/posee el NoteListenerWidget; nos lo
  /// expone para grabar el MISMO stream del micrófono). Null si el mic está off
  /// o todavía no arrancó.
  NoteDetector? _sharedDetector;

  /// Grabador para "grabar y reescuchar". Se usa cuando el mic está APAGADO
  /// (modo manual/MIDI/cámara). Con el mic ENCENDIDO graba el [_sharedDetector]
  /// (un solo micrófono para detectar y grabar a la vez).
  final PracticeRecorder _recorder = PracticeRecorder();
  bool _recordOn = false;

  /// Vista activa del cuerpo: secuencia / cascada / partitura (se cicla).
  _PlayView _playView = _PlayView.sequence;

  /// Servicio de entrada MIDI (null = desconectado). Cuando está activo, es la
  /// fuente de evaluación de máxima precisión y tiene prioridad sobre el mic.
  MidiInputService? _midiService;
  bool get _midiEnabled => _midiService != null;
  StreamSubscription<MidiNoteEvent>? _midiSynthSub;

  /// Aviso transitorio de error (se desvanece solo). Se dispara al detectar una
  /// nota mal; no bloquea la práctica.
  String? _wrongFlash;
  Timer? _wrongFlashTimer;
  int _seenWrongCount = 0;

  /// Título de la lección (para etiquetar la grabación en "Mis grabaciones").
  String? _lessonTitle;

  /// Metrónomo: tempo de la lección + estado del click y la cuenta de entrada.
  int _bpm = 80;
  bool _metronomeOn = false;
  Timer? _metronomeTimer;
  int _countIn = 0; // 4..1 durante la cuenta de entrada; 0 = apagado/normal
  bool _beatFlash = false;

  /// Sonido al acertar una nota (la app "suena"). Se silencia en modo
  /// micrófono para que el tono no se autodetecte como nota.
  final ToneSynth _synth = ToneSynth();
  int _lastCorrect = 0;
  String? _lastExpected;

  /// Ayuda de la barra de herramientas (leyenda de íconos): se auto-muestra una
  /// sola vez la primera práctica y queda disponible bajo el botón "?".
  final PracticeHelpService _helpService = PracticeHelpService();
  bool _helpChecked = false;

  /// Loop de sección (A-B): rango de notas a repetir.
  bool _loopOn = false;
  double _loopStart = 0;
  double _loopEnd = 0;

  /// La primera vez que la práctica arranca, muestra la leyenda de íconos (una
  /// sola vez). Se difiere al final del frame para no abrir la hoja mientras el
  /// árbol todavía se está construyendo.
  Future<void> _maybeShowToolbarHelp() async {
    if (_helpChecked) return;
    _helpChecked = true;
    if (await _helpService.hasSeenToolbarHelp() || !mounted) return;
    await _helpService.markToolbarHelpSeen();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) PracticeToolbarHelpSheet.show(context);
    });
  }

  void _toggleLoop(int total) {
    setState(() {
      _loopOn = !_loopOn;
      if (_loopOn) {
        _loopStart = 0;
        _loopEnd = (total - 1).toDouble();
      }
    });
    context.read<PracticeBloc>().add(
      PracticeSetLoop(
        enabled: _loopOn,
        start: _loopStart.round(),
        end: _loopEnd.round(),
      ),
    );
  }

  /// Stats de manos (cámara) acumuladas para alimentar el feedback con IA.
  int _hFrames = 0, _hWith = 0, _hLeft = 0, _hRight = 0;

  /// Postura: frames analizados y cuántos con dedos planos (poca curvatura).
  int _postureFrames = 0, _flatFrames = 0;

  /// Suavizado del tip en vivo (evita parpadeo): rachas de frames planos/buenos.
  int _flatStreak = 0, _goodStreak = 0;
  String? _postureTip;

  void _onHands(List<Hand> hands) {
    _hFrames++;
    if (hands.isEmpty) {
      // Sin manos: reiniciar rachas y limpiar el tip (no quedar pegado).
      _flatStreak = 0;
      _goodStreak = 0;
      if (_postureTip != null) setState(() => _postureTip = null);
      return;
    }
    _hWith++;
    var left = false, right = false;
    double? straightness;
    for (final h in hands) {
      if (h.landmarks.isEmpty) continue;
      var sx = 0.0;
      for (final p in h.landmarks) {
        sx += p.x;
      }
      final ax = sx / h.landmarks.length;
      if (ax < 0.5) {
        left = true;
      } else {
        right = true;
      }
      // Curvatura de la primera mano con landmarks completos.
      straightness ??= PostureAnalyzer.fingerStraightness(h.landmarks);
    }
    if (left) _hLeft++;
    if (right) _hRight++;

    // Postura: acumular y actualizar el tip en vivo con suavizado.
    if (straightness != null) {
      _postureFrames++;
      final flat = straightness > PostureAnalyzer.flatThreshold;
      if (flat) {
        _flatFrames++;
        _flatStreak++;
        _goodStreak = 0;
      } else {
        _goodStreak++;
        _flatStreak = 0;
      }
      // Mostrar el tip tras ~5 frames planos seguidos; ocultarlo tras ~3 buenos.
      final String? next = _flatStreak >= 5
          ? 'Curvá más los dedos 🤚'
          : (_goodStreak >= 3 ? null : _postureTip);
      if (next != _postureTip) setState(() => _postureTip = next);
    }
  }

  Map<String, dynamic>? _handTrackingEntry() {
    if (_hFrames == 0) return null;
    final entry = <String, dynamic>{
      'type': 'hand_tracking',
      'frames_total': _hFrames,
      'frames_with_hand_pct': (_hWith * 100 / _hFrames).round(),
      'left_hand_pct': (_hLeft * 100 / _hFrames).round(),
      'right_hand_pct': (_hRight * 100 / _hFrames).round(),
    };
    if (_postureFrames > 0) {
      entry['fingers_flat_pct'] = (_flatFrames * 100 / _postureFrames).round();
    }
    return entry;
  }

  /// Posición 1-based contando solo notas TOCABLES (sin silencios), para que el
  /// "Nota X de Y" nunca se pase del total. `currentPosition` es el índice crudo
  /// del array (incluye silencios y cada nota de un acorde), por eso no sirve
  /// directo: en lecciones con silencios/acordes daba "Nota 10 de 9".
  int _playablePosition(PracticePlaying state, int totalPlayable) {
    var n = 0;
    final upto = state.currentPosition.clamp(0, state.notes.length);
    for (var i = 0; i < upto; i++) {
      if (!state.notes[i].isRest) n++;
    }
    return (n + 1).clamp(1, totalPlayable < 1 ? 1 : totalPlayable);
  }

  bool _completing = false;

  /// Al completar: detiene la grabación (si la hay) y navega a resultados con
  /// el path del audio + las stats de manos.
  Future<void> _handleCompleted(
    String lessonId,
    PracticeCompleted state,
  ) async {
    if (_completing) return; // evitar doble navegación
    _completing = true;
    String? recordingPath;
    if (_recordOn) {
      // Con el mic encendido la grabación la lleva el detector (mismo stream);
      // con el mic apagado, el grabador propio.
      recordingPath = _micEnabled
          ? await _sharedDetector?.stopRecording()
          : await _recorder.stop();
      _recordOn = false;
    }
    final ht = _handTrackingEntry();
    if (!mounted) return;
    context.pushReplacement(
      '/practice/$lessonId/result',
      extra: {
        'score': state.score,
        'correctNotes': state.correctNotes,
        'totalNotes': state.totalNotes,
        'wrongNotes': state.wrongNotes,
        'averageTempo': state.averageTempo,
        'elapsedSeconds': state.elapsedSeconds,
        'errorsDetail': state.errorsDetail,
        'lessonTitle': _lessonTitle ?? 'Lección',
        'handTracking': ?ht,
        'recordingPath': ?recordingPath,
      },
    );
  }

  @override
  void initState() {
    super.initState();
    InstrumentService().get().then((i) {
      if (mounted) _synth.instrument = i;
    });
    _loadBpm();
  }

  Future<void> _loadBpm() async {
    try {
      final data = await context.read<LessonRepository>().getLessonDetail(
        widget.lessonId,
      );
      final lesson = data['lesson'] as LessonModel;
      if (mounted) {
        setState(() {
          _bpm = lesson.tempoBpm;
          _lessonTitle = lesson.title;
        });
        // Si el metrónomo ya estaba sonando con el tempo por defecto, lo
        // reprogramamos al tempo real recién cargado.
        if (_metronomeOn) _startMetronomeTimer();
      }
    } catch (_) {
      // Tempo por defecto si falla.
    }
  }

  void _startMetronomeTimer() {
    _metronomeTimer?.cancel();
    final intervalMs = (60000 / (_bpm <= 0 ? 80 : _bpm)).round();
    _metronomeTimer = Timer.periodic(
      Duration(milliseconds: intervalMs),
      (_) => _tick(),
    );
  }

  void _toggleMetronome() {
    if (_metronomeOn) {
      _metronomeTimer?.cancel();
      setState(() {
        _metronomeOn = false;
        _countIn = 0;
        _beatFlash = false;
      });
      return;
    }
    setState(() {
      _metronomeOn = true;
      _countIn = 4; // cuenta de entrada
    });
    _tick(); // primer tick inmediato
    _startMetronomeTimer();
  }

  void _tick() {
    if (!mounted) return;
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.selectionClick();
    setState(() {
      _beatFlash = true;
      if (_countIn > 0) _countIn--;
    });
    Timer(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => _beatFlash = false);
    });
  }

  void _flashWrong(String played, String expected) {
    _wrongFlashTimer?.cancel();
    setState(() => _wrongFlash = 'Tocaste $played · era $expected');
    _wrongFlashTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _wrongFlash = null);
    });
  }

  void _toggleMidi() {
    if (_midiService != null) {
      final svc = _midiService;
      _midiSynthSub?.cancel();
      _midiSynthSub = null;
      setState(() => _midiService = null);
      svc?.dispose();
      return;
    }
    final svc = MidiInputService();
    // Suena lo que tocás con DINÁMICA (velocity → volumen) y PEDAL (sustain →
    // tono más largo). El scoring lo maneja MidiListenerWidget por separado.
    _midiSynthSub = svc.noteOnStream.listen((e) {
      final sustained = svc.sustainOn.value;
      _synth.play(
        e.note,
        velocity: (e.velocity / 127).clamp(0.1, 1.0),
        seconds: sustained ? 1.8 : 0.6,
      );
    });
    setState(() => _midiService = svc);
    svc.start();
  }

  bool get _isPremium {
    final state = context.read<AuthBloc>().state;
    if (state is AuthAuthenticated) return state.user.isPremium;
    if (state is AuthRegistered) return state.user.isPremium;
    return false;
  }

  void _toggleCamera() {
    if (_handTrackerEnabled) {
      final tracker = _sharedTracker;
      setState(() {
        _handTrackerEnabled = false;
        _sharedTracker = null;
      });
      tracker?.dispose();
      return;
    }

    // El coach por cámara (detección de manos) es una función premium.
    if (!_isPremium) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('El coach por cámara es una función Premium.'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Ver planes',
            onPressed: () => context.push('/subscription/paywall'),
          ),
        ),
      );
      return;
    }

    setState(() {
      _sharedTracker = HandTracker();
      _handTrackerEnabled = true;
    });
  }

  Future<void> _toggleMic() async {
    // Si se está grabando, cerramos la grabación en curso al cambiar el mic (no
    // cambiamos de grabador a mitad de camino). El usuario la reactiva después.
    if (_recordOn) {
      if (_micEnabled) {
        await _sharedDetector?.stopRecording();
      } else {
        await _recorder.stop();
      }
      _recordOn = false;
    }
    if (!mounted) return;
    setState(() => _micEnabled = !_micEnabled);
  }

  Future<void> _toggleRecord() async {
    if (_recordOn) {
      // Detener (descarta lo grabado: solo se guarda al completar la lección).
      if (_micEnabled) {
        await _sharedDetector?.stopRecording();
      } else {
        await _recorder.stop();
      }
      if (mounted) setState(() => _recordOn = false);
      return;
    }
    // Iniciar. Con el mic ENCENDIDO grabamos el MISMO stream del detector (tocás
    // en vivo y se graba a la vez); con el mic apagado, el grabador propio.
    if (_micEnabled) {
      final det = _sharedDetector;
      if (det == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preparando el micrófono… probá de nuevo.'),
          ),
        );
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/practice_${DateTime.now().millisecondsSinceEpoch}.wav';
      await det.startRecording(path);
      if (!mounted) return;
      setState(() => _recordOn = true);
      return;
    }
    final ok = await _recorder.start();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo iniciar la grabación.')),
      );
      return;
    }
    setState(() => _recordOn = true);
  }

  /// Modo activo según las entradas prendidas. MIDI tiene prioridad (es la
  /// fuente de máxima precisión).
  _InputMode get _mode {
    if (_midiEnabled) return _InputMode.midi;
    if (_micEnabled && _handTrackerEnabled) return _InputMode.combined;
    if (_micEnabled) return _InputMode.mic;
    if (_handTrackerEnabled) return _InputMode.camera;
    return _InputMode.manual;
  }

  @override
  void dispose() {
    _wrongFlashTimer?.cancel();
    _metronomeTimer?.cancel();
    _midiSynthSub?.cancel();
    _synth.dispose();
    _recorder.dispose();
    _sharedTracker?.dispose();
    _midiService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lessonId = widget.lessonId;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Detector de notas (invisible): solo cuando se usa micrófono y NO
            // hay MIDI (MIDI tiene prioridad para no evaluar dos veces la nota).
            if (_micEnabled && !_midiEnabled)
              Positioned.fill(
                child: NoteListenerWidget(
                  onDetector: (d) => _sharedDetector = d,
                ),
              ),

            // Detector MIDI (invisible): evalúa la entrada del teclado digital.
            if (_midiService != null)
              Positioned.fill(
                child: MidiListenerWidget(service: _midiService!),
              ),

            BlocConsumer<PracticeBloc, PracticeState>(
              listener: (context, state) {
                // Aviso transitorio al fallar una nota (no bloquea: seguimos
                // en la misma nota hasta acertar).
                if (state is PracticePlaying &&
                    state.wrongCount > _seenWrongCount &&
                    state.lastWrongPlayed != null) {
                  _seenWrongCount = state.wrongCount;
                  _flashWrong(
                    state.lastWrongPlayed!,
                    state.lastWrongExpected ?? '',
                  );
                }
                // Sonido al acertar: reproducir la nota recién completada.
                // En micrófono se silencia (se autodetectaría); en MIDI ya suena
                // al pulsar la tecla (con dinámica/pedal), así que tampoco acá.
                if (state is PracticePlaying) {
                  // La primera vez, muestra la leyenda de íconos de la barra.
                  _maybeShowToolbarHelp();
                  // Reinicio en pantalla (Reiniciar / cambio de mano vuelve a 0):
                  // limpiar las stats de manos para que reflejen el intento.
                  if (state.correctCount == 0 && _lastCorrect > 0) {
                    _hFrames = 0;
                    _hWith = 0;
                    _hLeft = 0;
                    _hRight = 0;
                    _postureFrames = 0;
                    _flatFrames = 0;
                  }
                  // Mientras se GRABA no se reproduce el synth: su salida de
                  // audio resetea la sesión en dispositivos reales y trunca la
                  // grabación (~1s), y además se colaría como "beeps" en la
                  // interpretación grabada.
                  if (state.correctCount > _lastCorrect &&
                      _lastExpected != null &&
                      !_micEnabled &&
                      !_midiEnabled &&
                      !_recordOn) {
                    _synth.play(_lastExpected!, seconds: 0.5);
                  }
                  _lastCorrect = state.correctCount;
                  _lastExpected = state.currentExpectedNote;
                }
                if (state is PracticeCompleted) {
                  _handleCompleted(lessonId, state);
                }
              },
              builder: (context, state) {
                if (state is PracticeInitial) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  );
                }

                if (state is PracticeError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          state.message,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => context.pop(),
                          child: const Text('Volver'),
                        ),
                      ],
                    ),
                  );
                }

                if (state is PracticePlaying) {
                  return _buildPlaying(context, state);
                }

                if (state is PracticePaused) {
                  return _buildPaused(context, state);
                }

                if (state is PracticeCompleted) {
                  return _buildCompleted(context, state);
                }

                return const SizedBox.shrink();
              },
            ),

            // Aviso transitorio de error (no bloqueante, se desvanece solo).
            if (_wrongFlash != null)
              Positioned(
                top: 72,
                left: 24,
                right: 24,
                child: IgnorePointer(child: _buildWrongFlash(context)),
              ),

            // Cuenta de entrada del metrónomo (4-3-2-1).
            if (_countIn > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: AnimatedScale(
                      scale: _beatFlash ? 1.0 : 0.85,
                      duration: const Duration(milliseconds: 120),
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$_countIn',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 56,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWrongFlash(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: AnimatedOpacity(
        opacity: _wrongFlash != null ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: cs.error,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: cs.error.withValues(alpha: 0.4), blurRadius: 12),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.close, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _wrongFlash ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Layout del estado PracticePlaying. Tiene dos modos:
  /// - Camera OFF: layout vertical con secuencia + nota grande + digitación andina + botones
  /// - Camera ON: cámara full-width arriba + info compacta abajo
  Widget _buildPlaying(BuildContext context, PracticePlaying state) {
    final totalPlayable = state.notes.where((n) => !n.isRest).length;
    final completedPositions = <int>{};
    for (var i = 0; i < state.currentPosition; i++) {
      completedPositions.add(i);
    }

    return Column(
      children: [
        // Header con cerrar, timer, toggle mic/cámara y pausa
        _buildHeader(context, state),

        // Indicador del modo activo (manual / micrófono / cámara / combinado)
        _buildModeChip(context),

        // Selector de manos (solo si la lección tiene ambas manos)
        if (state.handFilterAvailable) _buildHandSelector(context, state),

        // Loop de sección (repetir un rango de notas)
        _buildLoopControl(context, state),

        // Barra de progreso
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: PracticeProgressBar(
            // Posición 0-based contando solo notas tocables (sin silencios ni
            // notas extra de acorde), para que no muestre "11 de 9 · 111%".
            currentPosition: _playablePosition(state, totalPlayable) - 1,
            totalNotes: totalPlayable,
          ),
        ),

        // Cuerpo: cámara > cascada > secuencia (según toggles)
        Expanded(
          child: _handTrackerEnabled
              ? _buildPlayingWithCamera(
                  context,
                  state,
                  totalPlayable,
                  completedPositions,
                )
              : switch (_playView) {
                  _PlayView.cascade => _buildPlayingCascade(
                    context,
                    state,
                    totalPlayable,
                  ),
                  _PlayView.staff => _buildPlayingStaff(
                    context,
                    state,
                    totalPlayable,
                  ),
                  _PlayView.sequence => _buildPlayingWithoutCamera(
                    context,
                    state,
                    totalPlayable,
                    completedPositions,
                  ),
                },
        ),
      ],
    );
  }

  /// Control de loop de sección: toggle + RangeSlider sobre las notas.
  Widget _buildLoopControl(BuildContext context, PracticePlaying state) {
    final cs = Theme.of(context).colorScheme;
    final total = state.notes.length;
    if (total < 2) return const SizedBox.shrink();
    final maxIdx = (total - 1).toDouble();
    final start = _loopStart.clamp(0.0, maxIdx);
    final end = _loopEnd.clamp(start, maxIdx);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: _loopOn ? 'Quitar loop' : 'Repetir una sección',
            icon: Icon(
              Icons.repeat,
              color: _loopOn ? cs.primary : cs.onSurfaceVariant,
            ),
            onPressed: () => _toggleLoop(total),
          ),
          if (_loopOn)
            Expanded(
              child: RangeSlider(
                min: 0,
                max: maxIdx,
                divisions: total - 1,
                values: RangeValues(start, end),
                labels: RangeLabels(
                  '${start.round() + 1}',
                  '${end.round() + 1}',
                ),
                activeColor: cs.primary,
                onChanged: (v) => setState(() {
                  _loopStart = v.start;
                  _loopEnd = v.end;
                }),
                onChangeEnd: (v) => context.read<PracticeBloc>().add(
                  PracticeSetLoop(
                    enabled: true,
                    start: v.start.round(),
                    end: v.end.round(),
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: Text(
                'Repetir una sección (A-B)',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  /// Selector segmentado de manos: Ambas / Izquierda / Derecha. Reinicia la
  /// práctica con las notas de la mano elegida (la lección tiene ambas).
  Widget _buildHandSelector(BuildContext context, PracticePlaying state) {
    final cs = Theme.of(context).colorScheme;

    Widget seg(String label, String? hand) {
      final selected = state.handFilter == hand;
      return GestureDetector(
        onTap: () {
          // Cambiar de mano reinicia la secuencia → el loop deja de aplicar.
          if (_loopOn) setState(() => _loopOn = false);
          context.read<PracticeBloc>().add(PracticeSetHand(hand));
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? cs.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : cs.onSurfaceVariant,
              fontSize: 13,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            seg('Ambas', null),
            seg('Izquierda', 'left'),
            seg('Derecha', 'right'),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, PracticePlaying state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(
              Icons.close,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onPressed: () => _showExitDialog(context),
          ),
          Text(
            '${state.elapsedSeconds.toStringAsFixed(0)}s',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
          // Ayuda: qué hace cada ícono (fijo, siempre visible).
          IconButton(
            tooltip: 'Ayuda: ¿qué hace cada ícono?',
            icon: Icon(
              Icons.help_outline,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onPressed: () => PracticeToolbarHelpSheet.show(context),
          ),
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip:
                        'Vista: ${_viewName(_playView)} (tocar para cambiar)',
                    icon: Icon(
                      _viewIcon(_playView),
                      color: _playView == _PlayView.sequence
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: () => setState(() {
                      _playView =
                          _PlayView.values[(_playView.index + 1) %
                              _PlayView.values.length];
                    }),
                  ),
                  IconButton(
                    tooltip: _recordOn
                        ? 'Detener grabación'
                        : 'Grabar mi audio',
                    icon: Icon(
                      _recordOn ? Icons.stop_circle : Icons.fiber_manual_record,
                      color: _recordOn
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onPressed: _toggleRecord,
                  ),
                  IconButton(
                    tooltip: _metronomeOn ? 'Apagar metrónomo' : 'Metrónomo',
                    icon: Icon(
                      Icons.av_timer,
                      color: _metronomeOn
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onPressed: _toggleMetronome,
                  ),
                  IconButton(
                    tooltip: _micEnabled
                        ? 'Apagar micrófono'
                        : 'Detectar mi audio con micrófono',
                    icon: Icon(
                      _micEnabled ? Icons.mic : Icons.mic_off,
                      color: _micEnabled
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onPressed: _toggleMic,
                  ),
                  IconButton(
                    tooltip: _midiEnabled
                        ? 'Desconectar entrada MIDI'
                        : 'Conectar dispositivo MIDI (máxima precisión)',
                    icon: Icon(
                      Icons.cable,
                      color: _midiEnabled
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onPressed: _toggleMidi,
                  ),
                  IconButton(
                    tooltip: _handTrackerEnabled
                        ? 'Ocultar cámara'
                        : 'Analizar mis manos con cámara',
                    icon: Icon(
                      _handTrackerEnabled
                          ? Icons.videocam
                          : Icons.videocam_outlined,
                      color: _handTrackerEnabled
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onPressed: _toggleCamera,
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.pause,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () =>
                        context.read<PracticeBloc>().add(const PracticePause()),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Layout sin cámara: nota grande, secuencia, digitación andina, botones.
  /// Vista cascada (falling notes): las notas caen hacia la target bar.
  Widget _buildPlayingCascade(
    BuildContext context,
    PracticePlaying state,
    int totalPlayable,
  ) {
    return Column(
      children: [
        const SizedBox(height: 4),
        Text(
          'Nota ${_playablePosition(state, totalPlayable)} de $totalPlayable · toca ${state.currentExpectedNote}',
          style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FallingNotesView(
              notes: state.notes,
              currentPosition: state.currentPosition,
              currentExpectedNote: state.currentExpectedNote,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildEvaluation(context, state),
        const SizedBox(height: 16),
      ],
    );
  }

  /// Vista partitura (pentagrama): la notación se desplaza siguiendo la nota
  /// actual; reutiliza los botones manuales de evaluación.
  Widget _buildPlayingStaff(
    BuildContext context,
    PracticePlaying state,
    int totalPlayable,
  ) {
    return Column(
      children: [
        const SizedBox(height: 4),
        Text(
          'Nota ${_playablePosition(state, totalPlayable)} de $totalPlayable · toca ${state.currentExpectedNote}',
          style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: StaffView(
              notes: state.notes,
              currentPosition: state.currentPosition,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildEvaluation(context, state),
        const SizedBox(height: 16),
      ],
    );
  }

  String _viewName(_PlayView v) => switch (v) {
    _PlayView.sequence => 'Secuencia',
    _PlayView.cascade => 'Cascada',
    _PlayView.staff => 'Partitura',
  };

  IconData _viewIcon(_PlayView v) => switch (v) {
    _PlayView.sequence => Icons.view_agenda,
    _PlayView.cascade => Icons.waterfall_chart,
    _PlayView.staff => Icons.queue_music,
  };

  Widget _buildPlayingWithoutCamera(
    BuildContext context,
    PracticePlaying state,
    int totalPlayable,
    Set<int> completedPositions,
  ) {
    return Column(
      children: [
        const Spacer(),

        // Nota actual grande
        Column(
          children: [
            Text(
              'Toca esta nota',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.currentExpectedNote,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 64,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Nota ${_playablePosition(state, totalPlayable)} de $totalPlayable',
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 12,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Secuencia de notas (scroll horizontal)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: NoteSequenceViewer(
            notes: state.notes,
            currentPosition: state.currentPosition,
            completedPositions: completedPositions,
          ),
        ),

        const Spacer(),

        // Guía de digitación andina
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _buildAndeanFingeringWidget(
            context,
            state.currentExpectedNote,
          ),
        ),

        const SizedBox(height: 16),

        // Evaluación según el modo (manual/cámara → botones; mic → automático)
        _buildEvaluation(context, state),

        const SizedBox(height: 24),
      ],
    );
  }

  /// Layout con cámara activa: cámara ocupa la mitad superior, info compacta abajo.
  Widget _buildPlayingWithCamera(
    BuildContext context,
    PracticePlaying state,
    int totalPlayable,
    Set<int> completedPositions,
  ) {
    return Column(
      children: [
        // Cámara: ocupa el espacio principal disponible arriba
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: HandTrackerCamera(
                fullScreen: true,
                externalTracker: _sharedTracker!,
                onHands: _onHands,
              ),
            ),
          ),
        ),

        // Tip de postura en vivo (cuando detecta dedos planos sostenidos).
        if (_postureTip != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: _buildPostureTip(context, _postureTip!),
          ),

        const SizedBox(height: 8),

        // Nota a tocar — versión compacta
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Toca',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    state.currentExpectedNote,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Nota ${_playablePosition(state, totalPlayable)} de $totalPlayable',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Theme.of(context).hintColor,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Guía de digitación andina compacta
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _buildAndeanFingeringWidget(
            context,
            state.currentExpectedNote,
          ),
        ),

        const SizedBox(height: 12),

        // Evaluación según el modo
        _buildEvaluation(context, state),

        const SizedBox(height: 12),
      ],
    );
  }

  /// Tip de postura en vivo (guía aproximada, no un juez): se muestra cuando la
  /// cámara detecta dedos planos de forma sostenida.
  Widget _buildPostureTip(BuildContext context, String tip) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.warning.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.warning.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lightbulb_outline,
              size: 15,
              color: AppTheme.warning,
            ),
            const SizedBox(width: 6),
            Text(
              tip,
              style: const TextStyle(
                color: AppTheme.warning,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Chip que muestra el modo activo, para que el usuario sepa cuál usa.
  Widget _buildModeChip(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (IconData icon, String label) = switch (_mode) {
      _InputMode.manual => (Icons.touch_app, 'Modo manual'),
      _InputMode.mic => (Icons.mic, 'Modo micrófono'),
      _InputMode.camera => (Icons.videocam, 'Modo cámara'),
      _InputMode.combined => (Icons.auto_awesome, 'Modo combinado'),
      _InputMode.midi => (Icons.cable, 'Modo MIDI · máxima precisión'),
    };
    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: cs.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Área de evaluación: en manual/cámara muestra los botones; con micrófono o
  /// MIDI muestra el estado de evaluación automática.
  Widget _buildEvaluation(BuildContext context, PracticePlaying state) {
    if (_midiEnabled || _micEnabled) return _buildAutoStatus(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_handTrackerEnabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              'La cámara detecta tus manos (postura y digitación). La nota la '
              'evalúan el micrófono o el MIDI; en modo solo cámara, marcá tu '
              'resultado.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 11,
              ),
            ),
          ),
        _buildActionButtons(context, state),
      ],
    );
  }

  /// Indicador de evaluación automática (modo MIDI / micrófono / combinado).
  Widget _buildAutoStatus(BuildContext context) {
    if (_midiEnabled) return _buildMidiStatus(context);
    final cs = Theme.of(context).colorScheme;
    final combined = _mode == _InputMode.combined;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.graphic_eq, color: cs.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                combined
                    ? 'Escuchando micrófono + cámara. Tocá la nota: avanza al '
                          'acertar; si fallás, se queda en la misma.'
                    : 'Escuchando el micrófono. Tocá la nota: avanza al acertar; '
                          'si fallás, se queda en la misma.',
                style: TextStyle(color: cs.onSurface, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Estado del modo MIDI: muestra si hay un teclado conectado y reacciona a la
  /// conexión/desconexión en vivo.
  Widget _buildMidiStatus(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ValueListenableBuilder<MidiDevice?>(
        valueListenable: _midiService!.connected,
        builder: (context, device, _) {
          final connected = device != null;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: (connected ? cs.primary : cs.tertiary).withValues(
                alpha: 0.08,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  connected ? Icons.cable : Icons.bluetooth_searching,
                  color: cs.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    connected
                        ? 'MIDI conectado: ${device.name}. Tocá la nota en el '
                              'instrumento: avanza al acertar; si fallás, se queda en la misma.'
                        : 'Buscando dispositivo MIDI (USB o Bluetooth)… Conectá tu '
                              'instrumento digital para máxima precisión.',
                    style: TextStyle(color: cs.onSurface, fontSize: 13),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, PracticePlaying state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                context.read<PracticeBloc>().add(
                  PracticeNoteCorrect(state.currentPosition),
                );
              },
              icon: const Icon(Icons.check, size: 20),
              label: const Text('Acierto'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                context.read<PracticeBloc>().add(
                  PracticeNoteWrong(
                    position: state.currentPosition,
                    expected: state.currentExpectedNote,
                    played: 'X',
                  ),
                );
              },
              icon: const Icon(Icons.close, size: 20),
              label: const Text('Error'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaused(BuildContext context, PracticePaused state) {
    // El estado PracticePaused cubre dos casos: un ERROR de nota (mostrar la
    // guía de digitación para reintentar) y una PAUSA real del usuario.
    if (state.errorMessage != null) {
      return _buildNoteError(context, state);
    }
    return _buildPauseCard(context, state);
  }

  /// Vista de error de nota: guía de digitación andina + reintentar la misma nota.
  Widget _buildNoteError(BuildContext context, PracticePaused state) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.warning_amber_rounded, color: cs.error, size: 48),
          const SizedBox(height: 16),
          Text(
            state.errorMessage!,
            style: TextStyle(color: cs.error, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          if (state.expectedNote != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _buildAndeanFingeringWidget(context, state.expectedNote),
            ),
          const SizedBox(height: 12),
          Text(
            'Correctas: ${state.correctCount} | Errores: ${state.wrongCount}',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () =>
                context.read<PracticeBloc>().add(const PracticeRetry()),
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar esta nota'),
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Tarjeta de pausa: anillo de progreso + estadísticas + acciones.
  Widget _buildPauseCard(BuildContext context, PracticePaused state) {
    final cs = Theme.of(context).colorScheme;
    final playable = state.notes.where((n) => !n.isRest).length;
    final rawDone = state.notes
        .take(state.currentPosition)
        .where((n) => !n.isRest)
        .length;
    final done = rawDone > playable ? playable : rawDone;
    final double progress = playable == 0
        ? 0.0
        : (done / playable).clamp(0.0, 1.0).toDouble();
    final attempts = state.correctCount + state.wrongCount;
    final accuracy = attempts == 0
        ? 100
        : (state.correctCount / attempts * 100).round();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cs.surfaceContainerHighest),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Anillo de progreso con el % en el centro
              SizedBox(
                width: 132,
                height: 132,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 132,
                      height: 132,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 9,
                        strokeCap: StrokeCap.round,
                        backgroundColor: cs.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(cs.primary),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pause_rounded, color: cs.primary, size: 24),
                        Text(
                          '${(progress * 100).round()}%',
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'En pausa',
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Llevás $done de $playable notas · tomate un respiro',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  _pauseStat(
                    context,
                    Icons.check_circle_outline,
                    '${state.correctCount}',
                    'Correctas',
                    AppTheme.success,
                  ),
                  _pauseStat(
                    context,
                    Icons.cancel_outlined,
                    '${state.wrongCount}',
                    'Errores',
                    cs.error,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _pauseStat(
                    context,
                    Icons.track_changes,
                    '$accuracy%',
                    'Precisión',
                    cs.primary,
                  ),
                  _pauseStat(
                    context,
                    Icons.timer_outlined,
                    _formatTime(state.elapsedSeconds),
                    'Tiempo',
                    cs.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  // Reanuda en la nota actual (mismo comportamiento de antes).
                  onPressed: () =>
                      context.read<PracticeBloc>().add(const PracticeRetry()),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Reanudar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      // Reinicia la lección desde la primera nota.
                      onPressed: () => context.read<PracticeBloc>().add(
                        const PracticeRestart(),
                      ),
                      icon: const Icon(Icons.replay, size: 18),
                      label: const Text('Reiniciar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.onSurface,
                        side: BorderSide(color: cs.surfaceContainerHighest),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showExitDialog(context),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Salir'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.error,
                        side: BorderSide(
                          color: cs.error.withValues(alpha: 0.4),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Formatea segundos a "Xs" (<1 min) o "m:ss" (≥1 min).
  String _formatTime(double seconds) {
    final s = seconds.round();
    if (s < 60) return '${s}s';
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }

  Widget _pauseStat(
    BuildContext context,
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompleted(BuildContext context, PracticeCompleted state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Calculando resultados...',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          '¿Salir de la práctica?',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          'Se perderá el progreso actual.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(
              'Cancelar',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              context.pop();
            },
            child: Text(
              'Salir',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  /// Widget de digitación para aerófonos andinos (Quena, Zampoña, Tarka)
  /// adaptado a la nota esperada y al instrumento activo.
  Widget _buildAndeanFingeringWidget(BuildContext context, String? note) {
    return ActiveInstrumentFingeringWidget(note: note);
  }
}
