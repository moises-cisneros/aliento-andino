import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../rankings/data/models/achievement_model.dart';
import '../../../rankings/presentation/widgets/achievement_unlocked_dialog.dart';
import '../../../rankings/presentation/widgets/xp_gained_popup.dart';
import '../../data/models/practice_session_model.dart';
import '../../data/repositories/practice_repository.dart';
import '../bloc/lessons/lessons_bloc.dart';
import '../bloc/lessons/lessons_event.dart';
import '../widgets/score_circle.dart';
import '../../../../core/practice/daily_goal_service.dart';
import '../../../../core/practice/recordings_service.dart';
import '../../../../core/theme/app_theme.dart';

/// Pantalla de resultados de la práctica.
class PracticeResultScreen extends StatefulWidget {
  final String lessonId;
  final Map<String, dynamic> resultData;

  const PracticeResultScreen({
    super.key,
    required this.lessonId,
    required this.resultData,
  });

  @override
  State<PracticeResultScreen> createState() => _PracticeResultScreenState();
}

class _PracticeResultScreenState extends State<PracticeResultScreen> {
  String? _aiFeedback;
  String? _feedbackError;
  bool _feedbackLoading = false;
  bool _pending = false; // true si la práctica se guardó sin conexión
  Timer? _pollTimer;
  bool _recordingSaved = false; // la grabación quedó en "Mis grabaciones"

  @override
  void initState() {
    super.initState();
    _autoSaveRecording();
    _submitResult();
  }

  /// Si la práctica dejó una grabación, la guarda en la biblioteca local
  /// ("Mis grabaciones"). Copia el archivo a almacenamiento permanente, así que
  /// el reproductor de esta pantalla (que usa el archivo temporal) sigue
  /// funcionando. Es best-effort: si falla, no rompe la pantalla.
  Future<void> _autoSaveRecording() async {
    final path = widget.resultData['recordingPath'] as String?;
    if (path == null || path.isEmpty) return;
    final rec = await RecordingsService().saveFromTemp(
      tempPath: path,
      lessonId: widget.lessonId,
      lessonTitle: (widget.resultData['lessonTitle'] as String?) ?? 'Lección',
      score: (widget.resultData['score'] as num?)?.toDouble() ?? 0.0,
    );
    if (rec != null && mounted) setState(() => _recordingSaved = true);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  /// El análisis con IA es una función premium. Para usuarios sin suscripción
  /// no se hace polling ni se muestra la tarjeta (solo el aviso de upsell).
  bool get _isPremium {
    final state = context.read<AuthBloc>().state;
    if (state is AuthAuthenticated) return state.user.isPremium;
    if (state is AuthRegistered) return state.user.isPremium;
    return false;
  }

  /// Poll cada 2 segundos hasta 60 segundos esperando el feedback de Gemini.
  void _startFeedbackPolling(String sessionId) {
    _pollTimer?.cancel();
    setState(() {
      _feedbackLoading = true;
      _feedbackError = null;
    });
    int attempts = 0;
    const maxAttempts = 30; // 30 x 2s = 60s
    final repo = context.read<PracticeRepository>();

    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      attempts++;
      try {
        final PracticeSessionModel session = await repo.getSession(sessionId);
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (session.aiFeedback != null && session.aiFeedback!.isNotEmpty) {
          setState(() {
            _aiFeedback = session.aiFeedback;
            _feedbackLoading = false;
            _feedbackError = null;
          });
          timer.cancel();
        } else if (attempts >= maxAttempts) {
          setState(() {
            _feedbackLoading = false;
            _feedbackError =
                'No se pudo generar el análisis en este momento. '
                'Tu resultado se guardó correctamente.';
          });
          timer.cancel();
        }
      } catch (_) {
        if (attempts >= maxAttempts) {
          if (mounted) {
            setState(() {
              _feedbackLoading = false;
              _feedbackError =
                  'No se pudo obtener el análisis en este momento. '
                  'Tu resultado se guardó correctamente.';
            });
          }
          timer.cancel();
        }
      }
    });
  }

  Future<void> _submitResult() async {
    try {
      final repo = context.read<PracticeRepository>();
      final data = widget.resultData;
      final score = (data['score'] as num?)?.toDouble() ?? 0.0;
      final correctNotes = data['correctNotes'] as int? ?? 0;
      final totalNotes = data['totalNotes'] as int? ?? 0;
      final wrongNotes = data['wrongNotes'] as int? ?? 0;
      final missedNotes = (totalNotes - correctNotes).clamp(0, totalNotes);
      final averageTempo = (data['averageTempo'] as num?)?.toDouble() ?? 0.0;
      final elapsedSeconds =
          (data['elapsedSeconds'] as num?)?.toDouble() ?? 0.0;
      final errorsDetail = List<Map<String, dynamic>>.from(
        data['errorsDetail'] as List<Map<String, dynamic>>? ?? const [],
      );
      // Stats de manos (cámara) → el backend las usa en el feedback con IA.
      final handTracking = data['handTracking'] as Map<String, dynamic>?;
      if (handTracking != null) errorsDetail.add(handTracking);

      // Acreditar el tiempo a la meta diaria (en minutos).
      if (elapsedSeconds > 0) {
        unawaited(DailyGoalService().addMinutes(elapsedSeconds / 60.0));
      }

      final result = await repo.submitPractice(
        lessonId: widget.lessonId,
        score: score,
        correctNotes: correctNotes,
        totalNotes: totalNotes,
        wrongNotes: wrongNotes,
        missedNotes: missedNotes,
        averageTempo: averageTempo,
        totalTimeSeconds: elapsedSeconds,
        errorsDetail: errorsDetail,
      );

      if (mounted) {
        final xpEarned = result['xp_earned'] as int? ?? 0;
        final newLevel = result['new_level'] as bool? ?? false;
        final currentLevel = result['current_level'] as int? ?? 1;
        final rawAchievements = result['new_achievements'] as List? ?? [];
        final newAchievements = rawAchievements
            .map((a) => AchievementModel.fromJson(a as Map<String, dynamic>))
            .toList();

        final immediateFeedback = result['ai_feedback'] as String?;
        final pending = result['pending'] == true;
        setState(() {
          _aiFeedback = immediateFeedback;
          _feedbackError = null;
          _pending = pending;
        });

        // La práctica actualizó el score: avisamos al LessonsBloc (app-wide)
        // para que refresque la ruta y el hero "Continuar tu ruta" cambie solo,
        // sin que el usuario tenga que deslizar para refrescar.
        context.read<LessonsBloc>().add(const LessonsRefresh());

        // Si Gemini todavía no terminó, hacer polling. Offline (pending) no se
        // hace polling: el feedback llegará cuando la práctica se sincronice.
        // El feedback con IA es premium: para usuarios sin suscripción el
        // backend no lo genera, así que no tiene sentido hacer polling.
        final session = result['session'] as PracticeSessionModel;
        if (!pending &&
            _isPremium &&
            (immediateFeedback == null || immediateFeedback.isEmpty)) {
          _startFeedbackPolling(session.id);
        }

        // Mostrar popup de XP ganada
        if (xpEarned > 0 && mounted) {
          _showXPPopup(xpEarned, newLevel, currentLevel);
        }

        // Mostrar diálogos de logros desbloqueados
        if (newAchievements.isNotEmpty && mounted) {
          await Future.delayed(const Duration(milliseconds: 500));
          for (final achievement in newAchievements) {
            if (!mounted) break;
            await AchievementUnlockedDialog.show(context, achievement);
          }
        }
      }
    } catch (_) {
      // Silenciar error de submit, la UI ya muestra resultados locales
    }
  }

  void _showXPPopup(int xpEarned, bool newLevel, int currentLevel) {
    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 60,
        left: 0,
        right: 0,
        child: Center(
          child: XPGainedPopup(
            xpEarned: xpEarned,
            newLevel: newLevel,
            currentLevel: currentLevel,
            onDismiss: () => overlayEntry.remove(),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(overlayEntry);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.resultData;
    final score = (data['score'] as num?)?.toDouble() ?? 0.0;
    final correctNotes = data['correctNotes'] as int? ?? 0;
    final totalNotes = data['totalNotes'] as int? ?? 0;
    final wrongNotes = data['wrongNotes'] as int? ?? 0;
    final averageTempo = (data['averageTempo'] as num?)?.toDouble() ?? 0.0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: _buildResultUI(
          context,
          score: score,
          correctNotes: correctNotes,
          totalNotes: totalNotes,
          wrongNotes: wrongNotes,
          averageTempo: averageTempo,
          aiFeedback: _aiFeedback,
          feedbackError: _feedbackError,
          feedbackLoading: _feedbackLoading,
        ),
      ),
    );
  }

  Widget _buildResultUI(
    BuildContext context, {
    required double score,
    required int correctNotes,
    required int totalNotes,
    required int wrongNotes,
    required double averageTempo,
    String? aiFeedback,
    String? feedbackError,
    bool feedbackLoading = false,
  }) {
    final missedNotes = (totalNotes - correctNotes).clamp(0, totalNotes);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),

          // Título
          Text(
            _resultTitle(score),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _resultSubtitle(score),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),

          // Banner offline: la práctica se guardó en cola y se sincronizará.
          if (_pending) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.warning.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    color: AppTheme.warning,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Guardado sin conexión. Se sincronizará al volver internet.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Score circle
          const SizedBox(height: 32),
          ScoreCircle(score: score, size: 160, strokeWidth: 10),

          // Stats
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _statRow(
                  'Notas correctas',
                  '$correctNotes/$totalNotes',
                  AppTheme.success,
                ),
                Divider(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  height: 24,
                ),
                _statRow(
                  'Errores',
                  '$wrongNotes',
                  Theme.of(context).colorScheme.error,
                ),
                Divider(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  height: 24,
                ),
                _statRow('Notas omitidas', '$missedNotes', AppTheme.warning),
                Divider(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  height: 24,
                ),
                _statRow(
                  'Tempo promedio',
                  '${averageTempo.toInt()} BPM',
                  Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),

          // Feedback de IA — función PREMIUM.
          // - Premium: muestra el análisis (con skeleton mientras Gemini procesa).
          // - Sin suscripción: muestra un aviso para hacerse Premium en vez del
          //   análisis, respetando los privilegios.
          if (_isPremium) ...[
            if (aiFeedback != null ||
                feedbackLoading ||
                feedbackError != null) ...[
              const SizedBox(height: 20),
              _AIFeedbackCard(
                feedback: aiFeedback,
                error: feedbackError,
                loading: feedbackLoading,
              ),
            ],
          ] else ...[
            const SizedBox(height: 20),
            _AIFeedbackLockedCard(
              onUpgrade: () => context.push('/subscription/paywall'),
            ),
          ],

          // Reproductor de la grabación (si se grabó la interpretación).
          if ((widget.resultData['recordingPath'] as String?) != null) ...[
            const SizedBox(height: 20),
            _RecordingPlayer(
              path: widget.resultData['recordingPath'] as String,
            ),
            if (_recordingSaved)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => context.push('/recordings'),
                  icon: const Icon(Icons.library_music_outlined, size: 18),
                  label: const Text('Guardada · Ver en Mis grabaciones'),
                ),
              ),
          ],

          // Botones
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => context.go('/lessons/${widget.lessonId}'),
              icon: const Icon(Icons.replay),
              label: const Text('Practicar de Nuevo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () => context.go('/lessons'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                side: BorderSide(color: Theme.of(context).dividerColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Volver a Lecciones'),
            ),
          ),
          SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  String _resultTitle(double score) {
    if (score >= 90) return '¡Excelente!';
    if (score >= 70) return '¡Muy Bien!';
    if (score >= 50) return 'Buen Intento';
    return 'Sigue Practicando';
  }

  String _resultSubtitle(double score) {
    if (score >= 90) return 'Dominas esta lección. ¡Increíble trabajo!';
    if (score >= 70) return 'Casi perfecto. Un poco más de práctica.';
    if (score >= 50) return 'Vas por buen camino. ¡No te rindas!';
    return 'La práctica hace al maestro. Inténtalo de nuevo.';
  }
}

/// Card del feedback IA con estado de loading mientras Gemini genera el texto.
class _AIFeedbackCard extends StatelessWidget {
  final String? feedback;
  final String? error;
  final bool loading;

  const _AIFeedbackCard({
    required this.feedback,
    required this.error,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary.withValues(alpha: 0.1),
            cs.secondary.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: cs.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'Análisis con IA',
                style: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (loading) ...[
                const SizedBox(width: 10),
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.primary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (feedback != null)
            Text(
              feedback!,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 14,
                height: 1.5,
              ),
            )
          else if (loading)
            // Skeleton lines mientras carga
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonLine(width: double.infinity),
                const SizedBox(height: 6),
                _SkeletonLine(width: double.infinity),
                const SizedBox(height: 6),
                _SkeletonLine(width: 200),
                const SizedBox(height: 10),
                Text(
                  'Analizando tu práctica…',
                  style: TextStyle(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            )
          else
            Text(
              error ?? 'No se pudo obtener el análisis.',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 14,
                height: 1.5,
              ),
            ),
        ],
      ),
    );
  }
}

/// Aviso de upsell para usuarios sin suscripción: el análisis con IA es Premium.
class _AIFeedbackLockedCard extends StatelessWidget {
  final VoidCallback onUpgrade;

  const _AIFeedbackLockedCard({required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary.withValues(alpha: 0.1),
            cs.secondary.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: cs.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'Análisis con IA',
                style: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.workspace_premium,
                      color: AppTheme.warning,
                      size: 12,
                    ),
                    SizedBox(width: 3),
                    Text(
                      'Premium',
                      style: TextStyle(
                        color: AppTheme.warning,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Hacete Premium para recibir feedback personalizado de cada práctica: '
            'qué mejorar, en qué notas fallaste y cómo avanzar más rápido.',
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: onUpgrade,
              icon: const Icon(Icons.workspace_premium, size: 18),
              label: const Text('Hazte Premium'),
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: Colors.white,
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
}

/// Reproductor de la grabación de la interpretación (play/pausa).
class _RecordingPlayer extends StatefulWidget {
  final String path;
  const _RecordingPlayer({required this.path});

  @override
  State<_RecordingPlayer> createState() => _RecordingPlayerState();
}

class _RecordingPlayerState extends State<_RecordingPlayer> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  bool _started = false; // ya se reprodujo al menos una vez (para resume)
  StreamSubscription<void>? _completeSub;

  @override
  void initState() {
    super.initState();
    _completeSub = _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playing = false;
          _started = false; // al terminar, el próximo play arranca de cero
        });
      }
    });
  }

  @override
  void dispose() {
    _completeSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      if (mounted) setState(() => _playing = false);
    } else {
      if (_started) {
        await _player.resume();
      } else {
        await _player.play(DeviceFileSource(widget.path));
        _started = true;
      }
      if (mounted) setState(() => _playing = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.surfaceContainerHighest),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggle,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: cs.primary,
                size: 26,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tu grabación',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _playing ? 'Reproduciendo…' : 'Escuchá cómo te salió',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  final double width;
  const _SkeletonLine({required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 12,
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
