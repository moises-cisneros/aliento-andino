import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/onboarding_page.dart';

/// Onboarding inicial: 4 pantallas swipeable explicando la propuesta de valor.
/// Al terminar redirige a /skill-assessment.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  static const _pages = <_PageData>[
    _PageData(
      icon: Icons.music_note,
      color: Color(0xFF06B6D4),
      title: 'Aprendé instrumentos andinos desde cero',
      description:
          'Lecciones interactivas para todos los niveles, desde tus primeras notas hasta piezas avanzadas.',
    ),
    _PageData(
      icon: Icons.auto_awesome,
      color: Color(0xFF8B5CF6),
      title: 'Feedback con IA en tiempo real',
      description:
          'Nuestro sistema escucha lo que tocás y te corrige nota por nota, midiendo precisión y tempo.',
    ),
    _PageData(
      icon: Icons.emoji_events,
      color: Color(0xFFF59E0B),
      title: 'Subí de nivel mientras practicás',
      description:
          'Ganá XP, desbloqueá logros y compará tu progreso semanal con la comunidad.',
    ),
    _PageData(
      icon: Icons.groups,
      color: Color(0xFF10B981),
      title: 'Comunidad de músicos',
      description:
          'Compartí tus avances, seguí a otros pianistas y aprendé en conjunto.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _isLast => _currentPage == _pages.length - 1;

  void _next() {
    if (_isLast) {
      context.go('/skill-assessment');
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _skip() {
    context.go('/skill-assessment');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with skip
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _skip,
                    child: Text(
                      'Saltar',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) {
                  final p = _pages[index];
                  return OnboardingPage(
                    icon: p.icon,
                    iconColor: p.color,
                    title: p.title,
                    description: p.description,
                  );
                },
              ),
            ),

            // Dots
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (i) {
                  final active = i == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    width: active ? 28 : 8,
                    decoration: BoxDecoration(
                      color: active
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.3,
                            ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),

            // CTA button
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _next,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _isLast ? 'Empezar' : 'Continuar',
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

class _PageData {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const _PageData({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });
}
