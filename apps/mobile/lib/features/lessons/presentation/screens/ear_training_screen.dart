import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/audio/instrument_service.dart';
import '../../../../core/audio/tone_synth.dart';
import '../../../../core/theme/app_theme.dart';

/// Entrenamiento de oído: la app toca un intervalo (dos notas) y el usuario lo
/// identifica. Reutiliza el [ToneSynth] para sonar sin assets. Sube el puntaje
/// y la racha por acierto.
class EarTrainingScreen extends StatefulWidget {
  const EarTrainingScreen({super.key});

  @override
  State<EarTrainingScreen> createState() => _EarTrainingScreenState();
}

/// Intervalos posibles (semitonos → nombre).
const List<(int, String)> _intervals = [
  (1, '2ª menor'),
  (2, '2ª mayor'),
  (3, '3ª menor'),
  (4, '3ª mayor'),
  (5, '4ª justa'),
  (7, '5ª justa'),
  (8, '6ª menor'),
  (9, '6ª mayor'),
  (12, 'Octava'),
];

const List<String> _noteNames = [
  'C',
  'C#',
  'D',
  'D#',
  'E',
  'F',
  'F#',
  'G',
  'G#',
  'A',
  'A#',
  'B',
];

String _midiName(int m) => '${_noteNames[m % 12]}${m ~/ 12 - 1}';

class _EarTrainingScreenState extends State<EarTrainingScreen> {
  final ToneSynth _synth = ToneSynth();
  final math.Random _rng = math.Random();

  late int _root;
  late int _interval; // semitonos del intervalo correcto
  late List<int> _options; // semitonos de las opciones
  int? _selected; // intervalo elegido (null = sin responder)
  int _score = 0;
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    InstrumentService().get().then((i) {
      if (mounted) _synth.instrument = i;
    });
    _next();
  }

  @override
  void dispose() {
    _synth.stopAll(); // cancela cualquier play() en vuelo (bump de epoch)
    _synth.dispose();
    super.dispose();
  }

  void _next() {
    // Raíz cómoda (C4..G4) para que la nota superior quede en rango audible.
    _root = 48 + _rng.nextInt(12); // C3..B3
    final correct = _intervals[_rng.nextInt(_intervals.length)];
    _interval = correct.$1;

    // 4 opciones: la correcta + 3 distractores distintos.
    final pool = _intervals.map((e) => e.$1).toList()..shuffle(_rng);
    final opts = <int>{_interval};
    for (final s in pool) {
      if (opts.length >= 4) break;
      opts.add(s);
    }
    _options = opts.toList()..shuffle(_rng);
    _selected = null;
    setState(() {});
    _play();
  }

  Future<void> _play() async {
    _synth.play(_midiName(_root), seconds: 0.8);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    _synth.play(_midiName(_root + _interval), seconds: 0.9);
  }

  void _answer(int semis) {
    if (_selected != null) return; // ya respondió
    setState(() {
      _selected = semis;
      if (semis == _interval) {
        _score++;
        _streak++;
      } else {
        _streak = 0;
      }
    });
    // Reproducir el intervalo correcto como refuerzo.
    _play();
  }

  String _nameFor(int semis) => _intervals.firstWhere((e) => e.$1 == semis).$2;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final answered = _selected != null;
    final wasCorrect = _selected == _interval;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Entrenamiento de oído'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Row(
                children: [
                  Icon(
                    Icons.local_fire_department,
                    color: AppTheme.warning,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$_streak',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.star, color: cs.primary, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '$_score',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Text(
              '¿Qué intervalo escuchaste?',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15),
            ),
            const SizedBox(height: 24),

            // Botón escuchar de nuevo
            GestureDetector(
              onTap: _play,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.volume_up_rounded,
                  color: cs.primary,
                  size: 52,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tocá para escuchar de nuevo',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: 28),

            // Opciones
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 2.6,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                physics: const NeverScrollableScrollPhysics(),
                children: _options.map((semis) {
                  final isCorrect = semis == _interval;
                  final isPicked = semis == _selected;
                  Color bg = cs.surface;
                  Color fg = cs.onSurface;
                  if (answered) {
                    if (isCorrect) {
                      bg = AppTheme.success.withValues(alpha: 0.18);
                      fg = AppTheme.success;
                    } else if (isPicked) {
                      bg = cs.error.withValues(alpha: 0.18);
                      fg = cs.error;
                    }
                  }
                  return GestureDetector(
                    onTap: () => _answer(semis),
                    child: Container(
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: answered && isCorrect
                              ? AppTheme.success
                              : cs.surfaceContainerHighest,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _nameFor(semis),
                        style: TextStyle(
                          color: fg,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // Feedback + siguiente
            if (answered) ...[
              Text(
                wasCorrect
                    ? '¡Correcto! Era ${_nameFor(_interval)}.'
                    : 'Era ${_nameFor(_interval)}.',
                style: TextStyle(
                  color: wasCorrect ? AppTheme.success : cs.error,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Siguiente',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ] else
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Salir'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cs.onSurfaceVariant,
                    side: BorderSide(color: Theme.of(context).dividerColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
