import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/audio/instrument_service.dart';
import '../../../../core/audio/tone_synth.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/note_sequence_model.dart';
import '../widgets/staff_view.dart';

/// Lectura a primera vista: la app dibuja una nota en el pentagrama y el usuario
/// la identifica por su nombre (Do, Re, Mi…). Reutiliza [StaffView] para la
/// notación y [ToneSynth] para reforzar el sonido al responder.
class SightReadingScreen extends StatefulWidget {
  const SightReadingScreen({super.key});

  @override
  State<SightReadingScreen> createState() => _SightReadingScreenState();
}

const Map<String, String> _solfege = {
  'C': 'Do',
  'D': 'Re',
  'E': 'Mi',
  'F': 'Fa',
  'G': 'Sol',
  'A': 'La',
  'B': 'Si',
};
const List<String> _letters = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
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

bool _isWhite(int m) => const [0, 2, 4, 5, 7, 9, 11].contains(m % 12);
String _midiName(int m) => '${_noteNames[m % 12]}${m ~/ 12 - 1}';

class _SightReadingScreenState extends State<SightReadingScreen> {
  final ToneSynth _synth = ToneSynth();
  final math.Random _rng = math.Random();

  late bool _treble;
  late String _noteName; // p.ej. "E4"
  late String _letter; // 'E'
  late List<String> _options; // letras
  String? _selected;
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
    _synth.stopAll();
    _synth.dispose();
    super.dispose();
  }

  void _next() {
    _treble = _rng.nextBool();
    // Treble: C4..A5 ; Bass: C2..A3 — solo teclas blancas (notas naturales).
    final lo = _treble ? 60 : 36;
    final hi = _treble ? 81 : 57;
    int m;
    do {
      m = lo + _rng.nextInt(hi - lo + 1);
    } while (!_isWhite(m));
    _noteName = _midiName(m);
    _letter = _noteName[0];

    final opts = <String>{_letter};
    final pool = List<String>.from(_letters)..shuffle(_rng);
    for (final l in pool) {
      if (opts.length >= 4) break;
      opts.add(l);
    }
    _options = opts.toList()..shuffle(_rng);
    _selected = null;
    setState(() {});
  }

  void _answer(String letter) {
    if (_selected != null) return;
    setState(() {
      _selected = letter;
      if (letter == _letter) {
        _score++;
        _streak++;
      } else {
        _streak = 0;
      }
    });
    _synth.play(_noteName, seconds: 0.9);
  }

  NoteSequenceModel get _note => NoteSequenceModel(
    id: '',
    position: 0,
    note: _noteName,
    duration: 1,
    hand: _treble ? 'right' : 'left',
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final answered = _selected != null;
    final wasCorrect = _selected == _letter;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Lectura en pentagrama'),
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
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text(
              '¿Qué nota está escrita?',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15),
            ),
            const SizedBox(height: 16),

            // Pentagrama con la nota a leer
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.surfaceContainerHighest),
              ),
              child: StaffView(notes: [_note], height: 220),
            ),
            const SizedBox(height: 20),

            // Opciones (solfeo)
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 2.8,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                physics: const NeverScrollableScrollPhysics(),
                children: _options.map((letter) {
                  final isCorrect = letter == _letter;
                  final isPicked = letter == _selected;
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
                    onTap: () => _answer(letter),
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
                        '${_solfege[letter]} ($letter)',
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

            if (answered) ...[
              Text(
                wasCorrect
                    ? '¡Correcto! Es ${_solfege[_letter]} ($_noteName).'
                    : 'Es ${_solfege[_letter]} ($_noteName).',
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
