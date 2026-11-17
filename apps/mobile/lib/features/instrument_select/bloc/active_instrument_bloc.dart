import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/audio/instrument.dart';

// ── Events ─────────────────────────────────────────────────────────────

abstract class ActiveInstrumentEvent extends Equatable {
  const ActiveInstrumentEvent();

  @override
  List<Object?> get props => [];
}

class SelectInstrumentEvent extends ActiveInstrumentEvent {
  final InstrumentType instrument;

  const SelectInstrumentEvent(this.instrument);

  @override
  List<Object?> get props => [instrument];
}

class LoadActiveInstrumentEvent extends ActiveInstrumentEvent {
  const LoadActiveInstrumentEvent();
}

// ── States ─────────────────────────────────────────────────────────────

class ActiveInstrumentState extends Equatable {
  final InstrumentType activeInstrument;

  const ActiveInstrumentState(this.activeInstrument);

  @override
  List<Object?> get props => [activeInstrument];
}

// ── Bloc ──────────────────────────────────────────────────────────────

/// BLoC global que gestiona el instrumento andino activo en toda la aplicación.
///
/// Persiste de inmediato la elección del usuario bajo la clave [prefsKey] en
/// [SharedPreferences] y cuenta con fallback a [InstrumentType.quena] ante
/// valores nulos o corruptos.
class ActiveInstrumentBloc
    extends Bloc<ActiveInstrumentEvent, ActiveInstrumentState> {
  static const String prefsKey = 'active_instrument';
  final SharedPreferences? _prefs;

  ActiveInstrumentBloc({
    SharedPreferences? prefs,
    InstrumentType? initialInstrument,
  }) : _prefs = prefs,
       super(
         ActiveInstrumentState(
           initialInstrument ?? _resolveInitialInstrument(prefs),
         ),
       ) {
    on<SelectInstrumentEvent>(_onSelectInstrument);
    on<LoadActiveInstrumentEvent>(_onLoadActiveInstrument);
  }

  /// Resuelve el instrumento inicial desde SharedPreferences con fallback a Quena.
  static InstrumentType _resolveInitialInstrument(SharedPreferences? prefs) {
    if (prefs == null) return InstrumentType.quena;
    final stored = prefs.getString(prefsKey);
    if (stored == null || stored.trim().isEmpty) return InstrumentType.quena;

    final normalized = stored.trim().toLowerCase();
    for (final type in InstrumentType.values) {
      if (type.name.toLowerCase() == normalized) {
        return type;
      }
    }
    // Fallback ante valor corrupto o no reconocido
    return InstrumentType.quena;
  }

  Future<void> _onSelectInstrument(
    SelectInstrumentEvent event,
    Emitter<ActiveInstrumentState> emit,
  ) async {
    if (state.activeInstrument == event.instrument) return;

    emit(ActiveInstrumentState(event.instrument));
    try {
      await _prefs?.setString(prefsKey, event.instrument.name);
    } catch (_) {
      // Ignorar fallos de escritura de preferencias de forma resiliente
    }
  }

  void _onLoadActiveInstrument(
    LoadActiveInstrumentEvent event,
    Emitter<ActiveInstrumentState> emit,
  ) {
    final instrument = _resolveInitialInstrument(_prefs);
    emit(ActiveInstrumentState(instrument));
  }
}
