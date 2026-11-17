import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';

/// Quiz de teoría musical: preguntas de opción múltiple sobre intervalos,
/// figuras, armaduras, dinámicas y lectura. Toma un subconjunto al azar por
/// partida, muestra una pregunta a la vez con explicación, y un puntaje final.
class TheoryQuizScreen extends StatefulWidget {
  const TheoryQuizScreen({super.key});

  @override
  State<TheoryQuizScreen> createState() => _TheoryQuizScreenState();
}

class _Q {
  final String prompt;
  final List<String> options;
  final int correct;
  final String explain;
  const _Q(this.prompt, this.options, this.correct, this.explain);
}

/// Banco de preguntas (teoría correcta). El índice `correct` apunta a la
/// opción verdadera.
const List<_Q> _bank = [
  _Q(
    '¿Cuántos semitonos hay en una octava?',
    ['7', '8', '10', '12'],
    3,
    'Una octava se divide en 12 semitonos iguales.',
  ),
  _Q(
    '¿Cuántas teclas blancas hay en una octava?',
    ['5', '7', '8', '12'],
    1,
    'Do, Re, Mi, Fa, Sol, La, Si: 7 notas naturales.',
  ),
  _Q(
    'La distancia entre Mi y Fa es de…',
    ['un tono', 'un semitono', 'tono y medio', 'dos tonos'],
    1,
    'Mi–Fa y Si–Do son los dos pares de notas naturales separados por un semitono.',
  ),
  _Q(
    '¿Cuántos sostenidos tiene la tonalidad de Sol mayor?',
    ['0', '1', '2', '3'],
    1,
    'Sol mayor tiene un sostenido: Fa♯.',
  ),
  _Q(
    'La figura que dura la mitad de una negra es la…',
    ['redonda', 'blanca', 'corchea', 'semicorchea'],
    2,
    'La corchea vale media negra; dos corcheas equivalen a una negra.',
  ),
  _Q(
    'Una redonda equivale a ¿cuántas negras?',
    ['2', '3', '4', '8'],
    2,
    'La redonda dura 4 tiempos en 4/4, es decir 4 negras.',
  ),
  _Q(
    'El intervalo Do–Sol es una…',
    ['3ª mayor', '4ª justa', '5ª justa', 'octava'],
    2,
    'De Do a Sol hay 7 semitonos: una quinta justa.',
  ),
  _Q(
    'El intervalo Do–Mi es una…',
    ['2ª mayor', '3ª menor', '3ª mayor', '4ª justa'],
    2,
    'De Do a Mi hay 4 semitonos: una tercera mayor.',
  ),
  _Q(
    '¿Qué alteración SUBE un semitono a la nota?',
    ['bemol (♭)', 'sostenido (♯)', 'becuadro (♮)', 'calderón'],
    1,
    'El sostenido sube medio tono; el bemol lo baja.',
  ),
  _Q(
    '¿Qué símbolo CANCELA una alteración previa?',
    ['sostenido (♯)', 'bemol (♭)', 'becuadro (♮)', 'ligadura'],
    2,
    'El becuadro devuelve la nota a su altura natural.',
  ),
  _Q(
    'La clave de Sol se usa principalmente para notas…',
    ['graves', 'agudas', 'percusión', 'silencios'],
    1,
    'La clave de Sol (segunda línea) se usa para el registro agudo.',
  ),
  _Q(
    'La clave de Fa se usa principalmente para notas…',
    ['agudas', 'graves', 'medias', 'corales'],
    1,
    'La clave de Fa (cuarta línea) cubre el registro grave.',
  ),
  _Q(
    '¿Cuántas líneas tiene un pentagrama?',
    ['4', '5', '6', '7'],
    1,
    'El pentagrama tiene 5 líneas y 4 espacios.',
  ),
  _Q(
    'El patrón de tonos de la escala mayor es…',
    ['T-T-S-T-T-T-S', 'T-S-T-T-S-T-T', 'T-T-T-S-T-T-S', 'S-T-T-T-S-T-T'],
    0,
    'Mayor: tono-tono-semitono-tono-tono-tono-semitono.',
  ),
  _Q(
    '¿Cuántos bemoles tiene Fa mayor?',
    ['0', '1', '2', '3'],
    1,
    'Fa mayor tiene un bemol: Si♭.',
  ),
  _Q(
    'Una blanca dura ¿cuántos tiempos en 4/4?',
    ['1', '2', '3', '4'],
    1,
    'La blanca vale 2 tiempos (dos negras).',
  ),
  _Q(
    'El compás 4/4 tiene ¿cuántos tiempos por compás?',
    ['2', '3', '4', '6'],
    2,
    'El numerador indica 4 tiempos por compás.',
  ),
  _Q(
    '"Forte" (f) indica tocar…',
    ['suave', 'fuerte', 'rápido', 'lento'],
    1,
    'Forte = fuerte; piano = suave.',
  ),
  _Q(
    '"Piano" (p) indica tocar…',
    ['fuerte', 'suave', 'agudo', 'grave'],
    1,
    'Piano = suave (de ahí el nombre del instrumento, "pianoforte").',
  ),
  _Q(
    '"Allegro" indica un tempo…',
    ['muy lento', 'lento', 'rápido', 'libre'],
    2,
    'Allegro es un tempo rápido y alegre.',
  ),
];

const int _questionsPerRound = 10;

class _TheoryQuizScreenState extends State<TheoryQuizScreen> {
  final math.Random _rng = math.Random();
  late List<_Q> _questions;
  int _index = 0;
  int? _selected;
  int _score = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    final pool = List<_Q>.from(_bank)..shuffle(_rng);
    _questions = pool.take(_questionsPerRound).toList();
    _index = 0;
    _selected = null;
    _score = 0;
    setState(() {});
  }

  void _answer(int i) {
    if (_selected != null) return;
    setState(() {
      _selected = i;
      if (i == _questions[_index].correct) _score++;
    });
  }

  void _nextQuestion() {
    setState(() {
      _index++;
      _selected = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final done = _index >= _questions.length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Quiz de teoría'),
        actions: [
          if (!done)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_index + 1}/${_questions.length}',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: done ? _buildResult(cs) : _buildQuestion(cs),
    );
  }

  Widget _buildQuestion(ColorScheme cs) {
    final q = _questions[_index];
    final answered = _selected != null;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (_index + (answered ? 1 : 0)) / _questions.length,
            backgroundColor: cs.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(cs.primary),
          ),
          const SizedBox(height: 24),
          Text(
            q.prompt,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          ...List.generate(q.options.length, (i) {
            final isCorrect = i == q.correct;
            final isPicked = i == _selected;
            Color bg = cs.surface;
            Color border = cs.surfaceContainerHighest;
            Color fg = cs.onSurface;
            if (answered) {
              if (isCorrect) {
                bg = AppTheme.success.withValues(alpha: 0.15);
                border = AppTheme.success;
                fg = AppTheme.success;
              } else if (isPicked) {
                bg = cs.error.withValues(alpha: 0.15);
                border = cs.error;
                fg = cs.error;
              }
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => _answer(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          q.options[i],
                          style: TextStyle(
                            color: fg,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (answered && isCorrect)
                        Icon(
                          Icons.check_circle,
                          color: AppTheme.success,
                          size: 20,
                        )
                      else if (answered && isPicked)
                        Icon(Icons.cancel, color: cs.error, size: 20),
                    ],
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          if (answered) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.surfaceContainerHighest),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: cs.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      q.explain,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _nextQuestion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  _index + 1 >= _questions.length
                      ? 'Ver resultado'
                      : 'Siguiente',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResult(ColorScheme cs) {
    final pct = _questions.isEmpty
        ? 0
        : (_score / _questions.length * 100).round();
    final good = pct >= 70;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            good ? Icons.emoji_events : Icons.school,
            size: 72,
            color: good ? AppTheme.warning : cs.primary,
          ),
          const SizedBox(height: 16),
          Text(
            '$_score / ${_questions.length} correctas',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            good
                ? '¡Muy bien! Dominás estos conceptos.'
                : 'Seguí practicando, ¡vas a mejorar!',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _start,
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Jugar de nuevo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: () => context.pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.onSurfaceVariant,
                side: BorderSide(color: Theme.of(context).dividerColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Salir'),
            ),
          ),
        ],
      ),
    );
  }
}
