import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/connectivity/offline_banner.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../lessons/data/models/practice_session_model.dart';
import '../../../lessons/data/repositories/practice_repository.dart';
import '../bloc/practice_history_bloc.dart';
import '../widgets/accuracy_trend_chart.dart';

/// Historial de prácticas pasadas con su gráfica de evolución (HU-10).
class PracticeHistoryScreen extends StatelessWidget {
  const PracticeHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => PracticeHistoryBloc(
        practiceRepository: ctx.read<PracticeRepository>(),
      )..add(const PracticeHistoryLoadRequested()),
      child: const _PracticeHistoryView(),
    );
  }
}

class _PracticeHistoryView extends StatefulWidget {
  const _PracticeHistoryView();

  @override
  State<_PracticeHistoryView> createState() => _PracticeHistoryViewState();
}

class _PracticeHistoryViewState extends State<_PracticeHistoryView> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      context.read<PracticeHistoryBloc>().add(
        const PracticeHistoryNextPageRequested(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Historial de prácticas')),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: BlocBuilder<PracticeHistoryBloc, PracticeHistoryState>(
              builder: (context, state) {
                switch (state.status) {
                  case PracticeHistoryStatus.initial:
                  case PracticeHistoryStatus.loading:
                    return const Center(child: CircularProgressIndicator());
                  case PracticeHistoryStatus.failure:
                    return _ErrorView(message: state.error ?? 'Error');
                  case PracticeHistoryStatus.loaded:
                    if (state.isEmpty) return const _EmptyView();
                    return _HistoryList(state: state, controller: _controller);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  final PracticeHistoryState state;
  final ScrollController controller;

  const _HistoryList({required this.state, required this.controller});

  @override
  Widget build(BuildContext context) {
    final items = state.items;
    return RefreshIndicator(
      onRefresh: () async {
        context.read<PracticeHistoryBloc>().add(
          const PracticeHistoryLoadRequested(),
        );
      },
      child: ListView.separated(
        key: const Key('practice_history_list'),
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: items.length + 2,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == 0) return AccuracyTrendChart(sessions: items);
          if (index == items.length + 1) {
            return _ListFooter(state: state);
          }
          return PracticeHistoryTile(session: items[index - 1]);
        },
      ),
    );
  }
}

class _ListFooter extends StatelessWidget {
  final PracticeHistoryState state;

  const _ListFooter({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Text(
              state.error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            TextButton(
              onPressed: () => context.read<PracticeHistoryBloc>().add(
                const PracticeHistoryNextPageRequested(),
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    return const SizedBox(height: 8);
  }
}

/// Fila de una práctica: lección, instrumento, fecha y porcentaje de acierto.
class PracticeHistoryTile extends StatelessWidget {
  final PracticeSessionModel session;

  const PracticeHistoryTile({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final percent = session.score.round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.lessonTitle ?? 'Lección',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      formatHistoryDate(session.createdAt),
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (session.lessonInstrument != null)
                      InstrumentBadge(instrument: session.lessonInstrument!),
                  ],
                ),
              ],
            ),
          ),
          Text(
            '$percent%',
            key: const Key('history_score'),
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: _scoreColor(context, session.score),
            ),
          ),
        ],
      ),
    );
  }

  Color _scoreColor(BuildContext context, double score) {
    if (score >= 80) return AppTheme.success;
    if (score >= 50) return AppTheme.warning;
    return Theme.of(context).colorScheme.error;
  }
}

/// Chip con el instrumento andino de la lección practicada.
class InstrumentBadge extends StatelessWidget {
  final String instrument;

  const InstrumentBadge({super.key, required this.instrument});

  static String labelFor(String instrument) {
    switch (instrument.toLowerCase()) {
      case 'quena':
        return 'Quena';
      case 'zampona':
      case 'zampoña':
        return 'Zampoña';
      case 'tarka':
        return 'Tarka';
      default:
        return instrument;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        labelFor(instrument),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// `dd/MM/yyyy` en hora local; vacío si la fecha no es válida.
String formatHistoryDate(String? iso) {
  final date = DateTime.tryParse(iso ?? '')?.toLocal();
  if (date == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 56, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'Aún no has completado prácticas. ¡Comienza hoy con tu Quena!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('history_empty_cta'),
              style: FilledButton.styleFrom(minimumSize: const Size(160, 52)),
              onPressed: () => context.go('/lessons'),
              child: const Text('Empezar a practicar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;

  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(160, 52)),
              onPressed: () => context.read<PracticeHistoryBloc>().add(
                const PracticeHistoryLoadRequested(),
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
