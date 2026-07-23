import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/skill_question_card.dart';

/// Cuestionario auto-declarado de 4 preguntas → mapea a beginner/intermediate/advanced.
/// El score total determina el nivel y se pasa a /assessment-result.
/// Si [isRetake] es true, el resultado actualiza el skill_level del usuario
/// logueado en vez de iniciar el flujo de registro.
class SkillAssessmentScreen extends StatefulWidget {
  final bool isRetake;
  const SkillAssessmentScreen({super.key, this.isRetake = false});

  @override
  State<SkillAssessmentScreen> createState() => _SkillAssessmentScreenState();
}

class _SkillAssessmentScreenState extends State<SkillAssessmentScreen> {
  static const _questions = <_Question>[
    _Question(
      title: '¿Hace cuánto tocás piano?',
      options: [
        _Option(label: 'Nunca toqué', icon: Icons.star_border, points: 0),
        _Option(label: 'Menos de 6 meses', icon: Icons.timer, points: 1),
        _Option(label: 'Entre 6 meses y 2 años', icon: Icons.update, points: 2),
        _Option(label: 'Más de 2 años', icon: Icons.workspace_premium, points: 3),
      ],
    ),
    _Question(
      title: '¿Sabés leer partituras?',
      options: [
        _Option(label: 'Para nada', icon: Icons.help_outline, points: 0),
        _Option(label: 'Reconozco algunas notas', icon: Icons.lightbulb_outline, points: 1),
        _Option(label: 'Sí, con tiempo', icon: Icons.menu_book, points: 2),
        _Option(label: 'Sí, fluido', icon: Icons.school, points: 3),
      ],
    ),
    _Question(
      title: '¿Conocés los acordes mayores y menores?',
      options: [
        _Option(label: 'No sé qué son', icon: Icons.question_mark, points: 0),
        _Option(label: 'Sé los más básicos', icon: Icons.thumb_up_outlined, points: 1),
        _Option(label: 'Manejo varios', icon: Icons.queue_music, points: 2),
        _Option(label: 'Conozco escalas e inversiones', icon: Icons.library_music, points: 3),
      ],
    ),
    _Question(
      title: '¿Podés tocar con ambas manos a la vez?',
      options: [
        _Option(label: 'Todavía no', icon: Icons.back_hand, points: 0),
        _Option(label: 'Piezas muy simples', icon: Icons.front_hand, points: 1),
        _Option(label: 'Sí, con ejercicios', icon: Icons.sign_language, points: 2),
        _Option(label: 'Sin problema, piezas complejas', icon: Icons.piano, points: 3),
      ],
    ),
  ];

  late final List<int?> _answers = List<int?>.filled(_questions.length, null);
  int _currentIndex = 0;

  bool get _hasAnswered => _answers[_currentIndex] != null;
  bool get _isLast => _currentIndex == _questions.length - 1;

  void _select(int optionIndex) {
    setState(() => _answers[_currentIndex] = optionIndex);
  }

  void _next() {
    if (!_hasAnswered) return;
    if (_isLast) {
      _finish();
      return;
    }
    setState(() => _currentIndex++);
  }

  void _back() {
    if (_currentIndex == 0) {
      context.pop();
      return;
    }
    setState(() => _currentIndex--);
  }

  void _finish() {
    int total = 0;
    for (var i = 0; i < _questions.length; i++) {
      final ans = _answers[i];
      if (ans != null) total += _questions[i].options[ans].points;
    }

    // Mapeo: 0-4 = beginner, 5-8 = intermediate, 9-12 = advanced
    final String level;
    if (total <= 4) {
      level = 'beginner';
    } else if (total <= 8) {
      level = 'intermediate';
    } else {
      level = 'advanced';
    }

    final retakeParam = widget.isRetake ? '&retake=1' : '';
    context.go('/assessment-result?level=$level$retakeParam');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = _questions[_currentIndex];
    final progress = (_currentIndex + 1) / _questions.length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _back,
        ),
        title: Text(
          'Paso ${_currentIndex + 1} de ${_questions.length}',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: theme.colorScheme.surfaceContainerHigh,
                ),
              ),
            ),

            // Question + options
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      q.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ...List.generate(q.options.length, (i) {
                      final opt = q.options[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SkillQuestionCard(
                          label: opt.label,
                          icon: opt.icon,
                          selected: _answers[_currentIndex] == i,
                          onTap: () => _select(i),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            // Next button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _hasAnswered ? _next : null,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _isLast ? 'Ver mi nivel' : 'Continuar',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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
}

class _Question {
  final String title;
  final List<_Option> options;
  const _Question({required this.title, required this.options});
}

class _Option {
  final String label;
  final IconData icon;
  final int points;
  const _Option({
    required this.label,
    required this.icon,
    required this.points,
  });
}
