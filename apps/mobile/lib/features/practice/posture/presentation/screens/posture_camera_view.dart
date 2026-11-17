import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:mobile/core/audio/instrument.dart';
import 'package:mobile/features/practice/posture/presentation/bloc/posture_bloc.dart';
import 'package:mobile/features/practice/presentation/widgets/posture_indicator_widget.dart';

/// [SUB-06-B] Vista de cámara con retroalimentación ergonómica postural.
///
/// Muestra la puntuación de postura 0–100 en tiempo real, un indicador de
/// alineación (verticalidad de cuello, nivelación de hombros y apertura de
/// codos) y las alertas correctivas emitidas por [PostureBloc]. La inferencia
/// es 100% on-device: ningún fotograma sale del dispositivo.
class PostureCameraView extends StatelessWidget {
  final InstrumentType instrument;
  const PostureCameraView({super.key, this.instrument = InstrumentType.quena});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PostureBloc(),
      child: _PostureContent(instrument: instrument),
    );
  }
}

class _PostureContent extends StatelessWidget {
  final InstrumentType instrument;
  const _PostureContent({required this.instrument});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Postura y alineación'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: BlocConsumer<PostureBloc, PostureState>(
          listenWhen: (prev, curr) => curr is! PostureAlignmentEvaluated,
          listener: (context, state) {
            if (state is PostureCameraPermissionDenied) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.message)));
            } else if (state is PostureError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: theme.colorScheme.error,
                ),
              );
            }
          },
          builder: (context, state) {
            return Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        _headline(state),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: _PostureScoreRing(state: state, theme: theme),
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: _FeedbackList(state: state, theme: theme),
                      ),
                      _actionButton(context, state),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                // [SUB-06-B] Visor ergonómico en el borde de la pantalla.
                if (state is PostureAlignmentEvaluated)
                  Positioned.fill(
                    child: PostureIndicatorWidget.fromState(state),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _headline(PostureState state) {
    if (state is PostureAlignmentEvaluated) {
      if (!state.isTracking) {
        return 'Buscando tu silueta… alineá rostro y torso con la cámara.';
      }
      return state.isErgonomic
          ? '¡Buena postura! Mantené la columna erguida.'
          : 'Ajustá tu postura según las indicaciones.';
    }
    if (state is PostureCameraPermissionDenied) {
      return state.message;
    }
    if (state is PostureError) {
      return state.message;
    }
    return 'Encuadrá tu cabeza y hombros para evaluar tu postura mientras tocás.';
  }

  Widget _actionButton(BuildContext context, PostureState state) {
    final bloc = context.read<PostureBloc>();
    final isMonitoring = state is PostureAlignmentEvaluated;

    if (isMonitoring) {
      return OutlinedButton(
        onPressed: () {
          HapticFeedback.selectionClick();
          bloc.add(const StopPostureMonitoringEvent());
        },
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 56),
        ),
        child: const Text('Detener'),
      );
    }

    return ElevatedButton(
      onPressed: () {
        HapticFeedback.selectionClick();
        bloc.add(StartPostureMonitoringEvent(instrument));
      },
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 56),
      ),
      child: const Text('Iniciar monitoreo'),
    );
  }
}

class _PostureScoreRing extends StatelessWidget {
  final PostureState state;
  final ThemeData theme;
  const _PostureScoreRing({required this.state, required this.theme});

  @override
  Widget build(BuildContext context) {
    double score = 0.0;
    bool tracking = false;
    if (state is PostureAlignmentEvaluated) {
      final s = state as PostureAlignmentEvaluated;
      score = s.postureScorePercentage;
      tracking = s.isTracking;
    }

    final color = !tracking
        ? theme.colorScheme.outline
        : score >= 75
        ? theme.colorScheme.primary
        : score >= 50
        ? Colors.orange
        : theme.colorScheme.error;

    return SizedBox(
      width: 180,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 180,
            height: 180,
            child: CircularProgressIndicator(
              value: (score / 100).clamp(0.0, 1.0),
              strokeWidth: 10,
              color: color,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tracking ? score.round().toString() : '—',
                style: theme.textTheme.displayMedium?.copyWith(color: color),
              ),
              Text(
                'postura',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeedbackList extends StatelessWidget {
  final PostureState state;
  final ThemeData theme;
  const _FeedbackList({required this.state, required this.theme});

  @override
  Widget build(BuildContext context) {
    if (state is! PostureAlignmentEvaluated) {
      return const SizedBox.shrink();
    }
    final s = state as PostureAlignmentEvaluated;
    final ergonomic = s.isTracking && s.isErgonomic;

    return ListView(
      children: [
        for (final msg in s.feedback)
          ListTile(
            dense: true,
            leading: Icon(
              ergonomic ? Icons.check_circle_outline : Icons.info_outline,
              color: ergonomic
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error,
            ),
            title: Text(msg, style: theme.textTheme.bodyMedium),
          ),
      ],
    );
  }
}
