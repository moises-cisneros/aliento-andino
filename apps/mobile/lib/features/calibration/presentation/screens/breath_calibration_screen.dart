import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:mobile/core/audio/instrument.dart';
import 'package:mobile/features/calibration/presentation/bloc/breath_calibration_bloc.dart';

/// [SUB-02-A] Pantalla del asistente guiado de calibración de "Soplo Suave".
///
/// Pide al estudiante un soplo continuo de 3 segundos, muestra un contador
/// circular de progreso y entrega feedback háptico. Al completar, el umbral
/// calibrado queda persistido localmente (HU-02).
class BreathCalibrationScreen extends StatelessWidget {
  final InstrumentType instrument;
  const BreathCalibrationScreen({
    super.key,
    this.instrument = InstrumentType.quena,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BreathCalibrationBloc(),
      child: _BreathCalibrationContent(instrument: instrument),
    );
  }
}

class _BreathCalibrationContent extends StatelessWidget {
  final InstrumentType instrument;
  const _BreathCalibrationContent({required this.instrument});

  static const double _requiredSeconds = 3.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calibración de soplo'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: BlocConsumer<BreathCalibrationBloc, BreathCalibrationState>(
          listener: (context, state) {
            if (state is BreathCalibrationCompleted) {
              HapticFeedback.mediumImpact();
            } else if (state is BreathCalibrationFailed) {
              HapticFeedback.heavyImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: theme.colorScheme.error,
                ),
              );
            } else if (state is BreathCalibrationPermissionDenied) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.message)));
            }
          },
          builder: (context, state) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  Text(
                    _instructionFor(state),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: _ProgressRing(state: state, theme: theme),
                  ),
                  const SizedBox(height: 16),
                  _subtitle(context, state),
                  const Spacer(),
                  _actionButton(context, state),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _instructionFor(BreathCalibrationState state) {
    if (state is BreathCalibrationCompleted) {
      return '¡Listo! Ajustamos la sensibilidad a tu soplo.';
    }
    if (state is BreathCalibrationProgress && state.secondsElapsed > 0) {
      return 'Mantén un soplo suave y constante…';
    }
    return 'Sopla de forma suave y continua durante 3 segundos para calibrar tu sensibilidad.';
  }

  Widget _subtitle(BuildContext context, BreathCalibrationState state) {
    final theme = Theme.of(context);
    String text;
    if (state is BreathCalibrationCompleted) {
      text =
          'Umbral calibrado: ${state.baselineRmsThreshold.toStringAsFixed(3)}';
    } else if (state is BreathCalibrationProgress && state.secondsElapsed > 0) {
      text = '${state.secondsElapsed.toStringAsFixed(1)} s de 3 s';
    } else {
      text = 'Toca "Iniciar" cuando estés listo.';
    }
    return Text(
      text,
      textAlign: TextAlign.center,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.outline,
      ),
    );
  }

  Widget _actionButton(BuildContext context, BreathCalibrationState state) {
    final bloc = context.read<BreathCalibrationBloc>();
    final inProgress =
        state is BreathCalibrationProgress && state.secondsElapsed > 0;

    if (inProgress) {
      // Botón de cancelar (≥48px, Ley de Fitts).
      return OutlinedButton(
        onPressed: () => bloc.add(const CancelBreathCalibrationEvent()),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 56),
        ),
        child: const Text('Cancelar'),
      );
    }

    final isDone = state is BreathCalibrationCompleted;
    return ElevatedButton(
      onPressed: () {
        HapticFeedback.selectionClick();
        final current = state;
        if (current is BreathCalibrationCompleted) {
          Navigator.of(context).maybePop(current.baselineRmsThreshold);
        } else {
          bloc.add(StartBreathCalibrationEvent(instrument));
        }
      },
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 56),
      ),
      child: Text(isDone ? 'Finalizar' : 'Iniciar calibración'),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  final BreathCalibrationState state;
  final ThemeData theme;
  const _ProgressRing({required this.state, required this.theme});

  @override
  Widget build(BuildContext context) {
    double value = 0.0;
    String center = '3';
    if (state is BreathCalibrationProgress) {
      final s = (state as BreathCalibrationProgress).secondsElapsed;
      value = (s / _BreathCalibrationContent._requiredSeconds).clamp(0.0, 1.0);
      final remaining = (_BreathCalibrationContent._requiredSeconds - s).clamp(
        0.0,
        3.0,
      );
      center = remaining.ceil().toString();
    } else if (state is BreathCalibrationCompleted) {
      value = 1.0;
      center = '✓';
    }

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
              value: value,
              strokeWidth: 10,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          Text(
            center,
            style: theme.textTheme.displayMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
