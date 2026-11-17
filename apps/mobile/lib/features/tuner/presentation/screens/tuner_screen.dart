import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/audio/instrument.dart';
import 'package:mobile/features/tuner/presentation/bloc/tuner_bloc.dart';
import 'package:mobile/features/tuner/presentation/widgets/tuner_gauge_widget.dart';

/// Pantalla interactiva del afinador cromático para instrumentos andinos.
class TunerScreen extends StatelessWidget {
  const TunerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          TunerBloc()
            ..add(const TunerStarted(instrument: InstrumentType.quena)),
      child: const _TunerScreenContent(),
    );
  }
}

class _TunerScreenContent extends StatelessWidget {
  const _TunerScreenContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Afinador Andino'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Guía de afinación',
            onPressed: () => _showHelpDialog(context),
          ),
        ],
      ),
      body: SafeArea(
        child: BlocConsumer<TunerBloc, TunerState>(
          listener: (context, state) {
            if (state is TunerPermissionDenied) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: theme.colorScheme.error,
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is TunerPermissionDenied) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.mic_off,
                        size: 64,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Permiso de Micrófono Requerido',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Aliento Andino necesita acceso al micrófono para detectar la frecuencia de tu instrumento en tiempo real de forma local.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(200, 52), // Ley de Fitts
                        ),
                        onPressed: () {
                          context.read<TunerBloc>().add(const TunerStarted());
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final active = state is TunerActiveState ? state : null;
            final isRunning = active != null;

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Selector de Instrumento Andino
                    SegmentedButton<InstrumentType>(
                      segments: const [
                        ButtonSegment(
                          value: InstrumentType.quena,
                          label: Text('Quena'),
                          icon: Icon(Icons.music_note),
                        ),
                        ButtonSegment(
                          value: InstrumentType.zampona,
                          label: Text('Zampoña'),
                          icon: Icon(Icons.grid_view),
                        ),
                        ButtonSegment(
                          value: InstrumentType.tarka,
                          label: Text('Tarka'),
                          icon: Icon(Icons.straighten),
                        ),
                      ],
                      selected: {active?.instrument ?? InstrumentType.quena},
                      onSelectionChanged: (newSelection) {
                        context.read<TunerBloc>().add(
                          TunerInstrumentChanged(newSelection.first),
                        );
                      },
                    ),
                    const SizedBox(height: 32),

                    // Dial y Aguja
                    TunerGaugeWidget(
                      cents: active?.centsDeviation ?? 0.0,
                      frequencyHz: active?.frequencyHz ?? 0.0,
                      noteName: active?.noteName ?? '--',
                      isTuned: active?.isTuned ?? false,
                      isSilent: active?.isSilent ?? true,
                      toleranceCents: active?.toleranceCents ?? 15.0,
                    ),

                    const SizedBox(height: 36),

                    // Botón Principal de Acción (Ley de Fitts: >= 52px)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isRunning
                              ? theme.colorScheme.errorContainer
                              : theme.colorScheme.primary,
                          foregroundColor: isRunning
                              ? theme.colorScheme.onErrorContainer
                              : theme.colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          if (isRunning) {
                            context.read<TunerBloc>().add(const TunerStopped());
                          } else {
                            context.read<TunerBloc>().add(const TunerStarted());
                          }
                        },
                        icon: Icon(isRunning ? Icons.stop : Icons.play_arrow),
                        label: Text(
                          isRunning ? 'Detener Afinador' : 'Iniciar Afinador',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cómo usar el afinador'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• Soplá de forma continua y suave a 15-20 cm del micrófono.'),
            SizedBox(height: 8),
            Text(
              '• Si la aguja está a la izquierda (CALADO), subí ligeramente la presión del soplo.',
            ),
            SizedBox(height: 8),
            Text(
              '• Si la aguja está a la derecha (ALTO), relajá el labio o abrí la embocadura.',
            ),
            SizedBox(height: 8),
            Text(
              '• La zona verde indica que estás dentro de la tolerancia afinada (±15 cents).',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}
