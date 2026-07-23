import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../data/onboarding_storage.dart';

/// Pantalla final del onboarding o retake: muestra el nivel asignado.
/// - Modo onboarding (default): guarda local + marca onboarding hecho + CTA register.
/// - Modo retake (`isRetake=true`): actualiza skill_level del user logueado via API
///   y vuelve al perfil.
class AssessmentResultScreen extends StatefulWidget {
  final String level; // "beginner" | "intermediate" | "advanced"
  final bool isRetake;

  const AssessmentResultScreen({
    super.key,
    required this.level,
    this.isRetake = false,
  });

  @override
  State<AssessmentResultScreen> createState() => _AssessmentResultScreenState();
}

class _AssessmentResultScreenState extends State<AssessmentResultScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.isRetake) {
      // Usuario logueado quiere actualizar su nivel → mandar al backend.
      context.read<AuthBloc>().add(
        AuthProfileUpdateRequested(skillLevel: widget.level),
      );
    } else {
      // Flujo onboarding inicial: persistir local para el register.
      final storage = context.read<OnboardingStorage>();
      storage.saveSkillLevel(widget.level);
      storage.markCompleted();
      context.read<AuthBloc>().add(AuthCheckRequested());
    }
  }

  ({IconData icon, Color color, String title, String description, String cta})
  get _content {
    final ctaText = widget.isRetake ? 'Guardar nivel' : 'Crear mi cuenta';
    switch (widget.level) {
      case 'advanced':
        return (
          icon: Icons.workspace_premium,
          color: const Color(0xFFF59E0B),
          title: 'Nivel Avanzado',
          description:
              'Tenés buenas bases. Vamos a desafiarte con piezas complejas, escalas modales e improvisación.',
          cta: ctaText,
        );
      case 'intermediate':
        return (
          icon: Icons.trending_up,
          color: const Color(0xFF8B5CF6),
          title: 'Nivel Intermedio',
          description:
              'Sabés lo básico y un poco más. Te vamos a sugerir lecciones para consolidar técnica y agregar repertorio.',
          cta: ctaText,
        );
      case 'beginner':
      default:
        return (
          icon: Icons.spa,
          color: const Color(0xFF10B981),
          title: 'Nivel Principiante',
          description:
              'Perfecto, empezás desde lo básico. Te vamos a guiar paso a paso, sin prisa y con todo el detalle.',
          cta: ctaText,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = _content;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            children: [
              const Spacer(flex: 1),

              // Hero icon
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      c.color.withValues(alpha: 0.3),
                      c.color.withValues(alpha: 0.05),
                    ],
                  ),
                ),
                child: Icon(c.icon, size: 96, color: c.color),
              ),
              const SizedBox(height: 32),

              // Pretitle
              Text(
                'Tu nivel sugerido',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),

              // Title
              Text(
                c.title,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: c.color,
                ),
              ),
              const SizedBox(height: 20),

              // Description
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  c.description,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // Primary CTA: depende del modo
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: () {
                    if (widget.isRetake) {
                      // Volver al perfil (ya disparamos el update en initState)
                      context.go('/profile');
                    } else {
                      context.go('/register');
                    }
                  },
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    c.cta,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Secondary: solo en onboarding inicial
              if (!widget.isRetake)
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: Text(
                    'Ya tengo cuenta',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
