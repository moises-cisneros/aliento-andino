import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/audio/instrument.dart';
import '../../../instrument_select/bloc/active_instrument_bloc.dart';
import '../../../instrument_select/presentation/widgets/instrument_selector_appbar.dart';
import '../../data/models/note_sequence_model.dart';
import 'falling_notes_view.dart';

/// Modo cascada con guía de digitación andina: las notas caen sobre la barra de
/// impacto ([FallingNotesView]) y a su lado se muestran los orificios de
/// Quena/Tarka o los tubos de Zampoña de la nota esperada
/// ([ActiveInstrumentFingeringWidget]). Todo reacciona al instrumento activo
/// ([ActiveInstrumentBloc]), incluida la tolerancia en cents.
class CascadeFingeringPanel extends StatelessWidget {
  final List<NoteSequenceModel> notes;
  final int currentPosition;
  final String? currentExpectedNote;

  /// Ancho reservado a la guía de digitación junto a la cascada.
  static const double sidePanelWidth = 104;

  const CascadeFingeringPanel({
    super.key,
    required this.notes,
    required this.currentPosition,
    this.currentExpectedNote,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActiveInstrumentBloc, ActiveInstrumentState>(
      builder: (context, state) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: FallingNotesView(
                notes: notes,
                currentPosition: currentPosition,
                currentExpectedNote: currentExpectedNote,
                toleranceCents: state.activeInstrument.defaultToleranceCents,
              ),
            ),
            const SizedBox(width: 8),
            // La guía se escala para caber en el alto disponible (la Quena
            // apila 7 orificios) sin desbordar el layout en pantallas chicas.
            SizedBox(
              width: sidePanelWidth,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: ActiveInstrumentFingeringWidget(
                    note: currentExpectedNote,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
