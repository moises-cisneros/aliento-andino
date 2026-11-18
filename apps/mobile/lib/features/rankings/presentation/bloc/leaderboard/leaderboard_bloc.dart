import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/audio/instrument.dart';
import '../../../../../core/network/network_error.dart';
import '../../../data/models/leaderboard_model.dart';
import '../../../data/repositories/ranking_repository.dart';

// ── Events ─────────────────────────────────────────────────────────────

abstract class LeaderboardEvent extends Equatable {
  const LeaderboardEvent();

  @override
  List<Object?> get props => [];
}

/// Carga el ranking del instrumento indicado (cambio de tab o primera carga).
class LeaderboardInstrumentSelected extends LeaderboardEvent {
  final InstrumentType instrument;

  const LeaderboardInstrumentSelected(this.instrument);

  @override
  List<Object?> get props => [instrument];
}

/// Recarga el ranking del instrumento actual (pull-to-refresh / reintentar).
class LeaderboardRefreshed extends LeaderboardEvent {
  const LeaderboardRefreshed();
}

// ── State ──────────────────────────────────────────────────────────────

enum LeaderboardStatus { initial, loading, success, failure }

class LeaderboardState extends Equatable {
  final LeaderboardStatus status;
  final InstrumentType instrument;
  final List<LeaderboardEntryModel> items;

  /// Posición del usuario; null = sin prácticas esta semana ("Sin clasificar").
  final int? userRank;
  final String? message;

  const LeaderboardState({
    this.status = LeaderboardStatus.initial,
    this.instrument = InstrumentType.quena,
    this.items = const [],
    this.userRank,
    this.message,
  });

  @override
  List<Object?> get props => [status, instrument, items, userRank, message];
}

// ── Bloc ───────────────────────────────────────────────────────────────

/// BLoC del leaderboard semanal por instrumento (HU-12 / SUB-12-B).
///
/// Si el usuario cambia de instrumento mientras hay una petición en vuelo, la
/// respuesta tardía del instrumento anterior se descarta: el podio siempre
/// corresponde al tab seleccionado.
class LeaderboardBloc extends Bloc<LeaderboardEvent, LeaderboardState> {
  final RankingRepository rankingRepository;

  LeaderboardBloc({
    required this.rankingRepository,
    InstrumentType initialInstrument = InstrumentType.quena,
  }) : super(LeaderboardState(instrument: initialInstrument)) {
    on<LeaderboardInstrumentSelected>(
      (event, emit) => _load(event.instrument, emit),
    );
    on<LeaderboardRefreshed>((event, emit) => _load(state.instrument, emit));
  }

  Future<void> _load(
    InstrumentType instrument,
    Emitter<LeaderboardState> emit,
  ) async {
    emit(
      LeaderboardState(
        status: LeaderboardStatus.loading,
        instrument: instrument,
      ),
    );
    try {
      final data = await rankingRepository.getInstrumentLeaderboard(
        instrument.name,
      );
      // Tab cambiado mientras la petición estaba en vuelo: respuesta obsoleta.
      if (state.instrument != instrument) {
        return;
      }
      emit(
        LeaderboardState(
          status: LeaderboardStatus.success,
          instrument: instrument,
          items: data.items,
          userRank: data.userRank,
        ),
      );
    } catch (e) {
      if (state.instrument != instrument) return;
      emit(
        LeaderboardState(
          status: LeaderboardStatus.failure,
          instrument: instrument,
          message: isConnectionError(e)
              ? offlineMessage
              : 'Error al cargar el ranking de ${instrument.displayName}',
        ),
      );
    }
  }
}
