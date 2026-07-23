import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../data/tutor_repository.dart';
import 'tutor_action_executor.dart';
import 'tutor_sheet.dart';

/// Botón flotante del agente tutor "Vivi". Abre la hoja de conversación.
class TutorButton extends StatelessWidget {
  const TutorButton({super.key});

  void _open(BuildContext context) {
    final repository = context.read<TutorRepository>();
    final executor = TutorActionExecutor();
    // Pantalla donde está el usuario, para dársela como contexto a Vivi.
    final currentRoute = GoRouterState.of(context).matchedLocation;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (_) => TutorSheet(
        repository: repository,
        executor: executor,
        currentRoute: currentRoute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FloatingActionButton.small(
      heroTag: 'tutor_fab',
      backgroundColor: cs.secondaryContainer,
      foregroundColor: cs.onSecondaryContainer,
      tooltip: 'Tutor IA',
      onPressed: () => _open(context),
      child: const Icon(Icons.auto_awesome),
    );
  }
}
