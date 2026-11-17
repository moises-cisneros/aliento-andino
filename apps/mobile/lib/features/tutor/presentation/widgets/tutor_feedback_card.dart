import 'package:flutter/material.dart';
import 'package:mobile/core/audio/instrument.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/tutor/tutor_prompt_builder.dart';

/// Tarjeta visual que presenta el consejo pedagógico generado por el tutor SLM On-Device
/// o su fallback determinista tras finalizar una práctica musical.
///
/// Diseñada bajo las pautas ergonómicas de `apps/mobile/DESIGN.md` con radio de 16px,
/// contraste accesible y áreas táctiles de interacción >= 48px x 48px (Ley de Fitts).
class TutorFeedbackCard extends StatelessWidget {
  /// Texto del consejo pedagógico generado. Si es nulo o vacío, muestra el consejo predeterminado.
  final String? feedback;

  /// Instrumento andino asociado a la práctica evaluada.
  final InstrumentType? instrument;

  /// Indica si la inferencia pedagógica local está en progreso.
  final bool isLoading;

  /// Mensaje de error si la inferencia falló críticamente (activa fallback visual).
  final String? errorMessage;

  /// Callback opcional cuando el estudiante presiona el botón de acción/entendido.
  final VoidCallback? onAcknowledge;

  /// Callback opcional para reintentar la inferencia pedagógica.
  final VoidCallback? onRetry;

  const TutorFeedbackCard({
    super.key,
    this.feedback,
    this.instrument,
    this.isLoading = false,
    this.errorMessage,
    this.onAcknowledge,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final resolvedFeedback = _resolveFeedbackText();
    final instrumentLabel = _getInstrumentLabel(instrument);

    return Container(
      key: const Key('tutor_feedback_card'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Encabezado de la tarjeta con badge del Tutor Andino
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.cyan.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.cyan.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.auto_awesome,
                      color: AppTheme.cyan,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Tutor Pedagógico',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? const Color(0xFFE2E8F0)
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'On-Device',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Consejo para $instrumentLabel',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFF1E293B)),

          // Cuerpo de la tarjeta: Carga o contenido pedagógico
          Padding(
            padding: const EdgeInsets.all(16),
            child: isLoading
                ? _buildLoadingState(theme)
                : _buildFeedbackContent(theme, resolvedFeedback, isDark),
          ),

          // Acciones de interacción ergonómicas (mínimo 48px de altura táctil)
          if (!isLoading)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  if (onRetry != null &&
                      (errorMessage != null || feedback == null))
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          key: const Key('tutor_retry_button'),
                          onPressed: onRetry,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.cyan),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.refresh, size: 20),
                          label: const Text('Reintentar'),
                        ),
                      ),
                    ),
                  if (onRetry != null &&
                      (errorMessage != null || feedback == null))
                    const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        key: const Key('tutor_acknowledge_button'),
                        onPressed: onAcknowledge ?? () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.cyan,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.check_circle_outline, size: 20),
                        label: const Text(
                          '¡Entendido!',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Column(
      key: const Key('tutor_loading_indicator'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.cyan),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Sintetizando análisis con SLM local...',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppTheme.muted,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFeedbackContent(ThemeData theme, String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.lightbulb_outline,
              color: AppTheme.warning,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              key: const Key('tutor_feedback_text'),
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.45,
                color: isDark
                    ? const Color(0xFFCBD5E1)
                    : const Color(0xFF334155),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _resolveFeedbackText() {
    if (errorMessage != null && errorMessage!.isNotEmpty) {
      return TutorPromptBuilder.defaultPedagogicalAdvice;
    }
    if (feedback == null || feedback!.trim().isEmpty) {
      return TutorPromptBuilder.defaultPedagogicalAdvice;
    }
    return feedback!.trim();
  }

  String _getInstrumentLabel(InstrumentType? type) {
    switch (type) {
      case InstrumentType.quena:
        return 'Quena';
      case InstrumentType.zampona:
        return 'Zampoña';
      case InstrumentType.tarka:
        return 'Tarka';
      case null:
        return 'Instrumento Andino';
    }
  }
}
