import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/audio/instrument.dart';
import '../../../lessons/presentation/widgets/instruments/quena_fingering_widget.dart';
import '../../../lessons/presentation/widgets/instruments/tarka_fingering_widget.dart';
import '../../../lessons/presentation/widgets/instruments/zampona_fingering_widget.dart';
import '../../bloc/active_instrument_bloc.dart';

/// Helper para icono visual de cada instrumento andino.
IconData getInstrumentIcon(InstrumentType type) {
  switch (type) {
    case InstrumentType.quena:
      return Icons.music_note;
    case InstrumentType.zampona:
      return Icons.grid_view;
    case InstrumentType.tarka:
      return Icons.straighten;
  }
}

/// Acción ergonómica para AppBar que muestra el instrumento andino activo y
/// permite conmutarlo dinámicamente con un solo toque (Ley de Fitts >= 48x48px).
class InstrumentSelectorAction extends StatelessWidget {
  const InstrumentSelectorAction({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BlocBuilder<ActiveInstrumentBloc, ActiveInstrumentState>(
      builder: (context, state) {
        final active = state.activeInstrument;

        return PopupMenuButton<InstrumentType>(
          key: const Key('instrument-selector-appbar-button'),
          tooltip: 'Cambiar instrumento activo (actual: ${active.displayName})',
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          position: PopupMenuPosition.under,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onSelected: (selected) {
            context.read<ActiveInstrumentBloc>().add(
              SelectInstrumentEvent(selected),
            );
          },
          itemBuilder: (context) {
            return InstrumentType.values.map((instrument) {
              final isSelected = instrument == active;
              return PopupMenuItem<InstrumentType>(
                key: Key('instrument-option-${instrument.name}'),
                value: instrument,
                height: 52, // Ley de Fitts: >= 48px para ergonomía táctil
                child: Row(
                  children: [
                    Icon(
                      getInstrumentIcon(instrument),
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        instrument.displayName,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                  ],
                ),
              );
            }).toList();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
            child: Container(
              height: 48,
              constraints: const BoxConstraints(minWidth: 48),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    getInstrumentIcon(active),
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    active.displayName,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// AppBar estándar de navegación principal que incluye el selector de instrumento
/// andino activo en sus acciones.
class InstrumentSelectorAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final Widget? title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool automaticallyImplyLeading;
  final Widget? leading;
  final bool centerTitle;
  final Color? backgroundColor;

  const InstrumentSelectorAppBar({
    super.key,
    this.title,
    this.actions,
    this.bottom,
    this.automaticallyImplyLeading = true,
    this.leading,
    this.centerTitle = true,
    this.backgroundColor,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0.0));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: title,
      centerTitle: centerTitle,
      automaticallyImplyLeading: automaticallyImplyLeading,
      leading: leading,
      backgroundColor: backgroundColor,
      bottom: bottom,
      actions: [...?actions, const InstrumentSelectorAction()],
    );
  }
}

/// Widget de digitación adaptativo que se reconfigura en tiempo real
/// según el [InstrumentType] emitido por [ActiveInstrumentBloc].
class ActiveInstrumentFingeringWidget extends StatelessWidget {
  final String? note;
  final InstrumentType? overrideInstrument;

  const ActiveInstrumentFingeringWidget({
    super.key,
    this.note,
    this.overrideInstrument,
  });

  @override
  Widget build(BuildContext context) {
    if (overrideInstrument != null) {
      return _buildInstrumentWidget(overrideInstrument!, note);
    }

    return BlocBuilder<ActiveInstrumentBloc, ActiveInstrumentState>(
      builder: (context, state) {
        return _buildInstrumentWidget(state.activeInstrument, note);
      },
    );
  }

  Widget _buildInstrumentWidget(InstrumentType active, String? note) {
    switch (active) {
      case InstrumentType.quena:
        return QuenaFingeringWidget(
          key: const Key('active-quena-fingering'),
          note: note,
        );
      case InstrumentType.zampona:
        return ZamponaFingeringWidget(
          key: const Key('active-zampona-fingering'),
          note: note,
        );
      case InstrumentType.tarka:
        return TarkaFingeringWidget(
          key: const Key('active-tarka-fingering'),
          note: note,
        );
    }
  }
}
