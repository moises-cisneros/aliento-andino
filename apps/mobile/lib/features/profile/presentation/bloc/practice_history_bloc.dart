import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/network_error.dart';
import '../../../lessons/data/models/practice_session_model.dart';
import '../../../lessons/data/repositories/practice_repository.dart';

/// Eventos del historial de prácticas.
abstract class PracticeHistoryEvent extends Equatable {
  const PracticeHistoryEvent();

  @override
  List<Object?> get props => [];
}

/// Carga (o recarga) la primera página.
class PracticeHistoryLoadRequested extends PracticeHistoryEvent {
  const PracticeHistoryLoadRequested();
}

/// Carga la siguiente página y la agrega al final.
class PracticeHistoryNextPageRequested extends PracticeHistoryEvent {
  const PracticeHistoryNextPageRequested();
}

enum PracticeHistoryStatus { initial, loading, loaded, failure }

class PracticeHistoryState extends Equatable {
  final PracticeHistoryStatus status;
  final List<PracticeSessionModel> items;
  final int page;
  final bool hasMore;
  final bool loadingMore;
  final String? error;

  const PracticeHistoryState({
    this.status = PracticeHistoryStatus.initial,
    this.items = const [],
    this.page = 0,
    this.hasMore = false,
    this.loadingMore = false,
    this.error,
  });

  /// Cargó bien pero no hay ninguna práctica registrada.
  bool get isEmpty => status == PracticeHistoryStatus.loaded && items.isEmpty;

  PracticeHistoryState copyWith({
    List<PracticeSessionModel>? items,
    int? page,
    bool? hasMore,
    bool? loadingMore,
    String? error,
  }) {
    return PracticeHistoryState(
      status: status,
      items: items ?? this.items,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, items, page, hasMore, loadingMore, error];
}

/// BLoC del historial paginado de prácticas (HU-10).
class PracticeHistoryBloc
    extends Bloc<PracticeHistoryEvent, PracticeHistoryState> {
  static const pageSize = 20;

  final PracticeRepository _repository;

  PracticeHistoryBloc({required PracticeRepository practiceRepository})
    : _repository = practiceRepository,
      super(const PracticeHistoryState()) {
    on<PracticeHistoryLoadRequested>(_onLoad);
    on<PracticeHistoryNextPageRequested>(_onNextPage);
  }

  Future<void> _onLoad(
    PracticeHistoryLoadRequested event,
    Emitter<PracticeHistoryState> emit,
  ) async {
    emit(const PracticeHistoryState(status: PracticeHistoryStatus.loading));
    try {
      final result = await _fetch(1);
      emit(
        PracticeHistoryState(
          status: PracticeHistoryStatus.loaded,
          items: result.items,
          page: 1,
          hasMore: result.hasMore,
        ),
      );
    } catch (e) {
      emit(
        PracticeHistoryState(
          status: PracticeHistoryStatus.failure,
          error: _friendlyError(e),
        ),
      );
    }
  }

  Future<void> _onNextPage(
    PracticeHistoryNextPageRequested event,
    Emitter<PracticeHistoryState> emit,
  ) async {
    if (state.status != PracticeHistoryStatus.loaded ||
        !state.hasMore ||
        state.loadingMore) {
      return;
    }
    emit(state.copyWith(loadingMore: true));
    try {
      final next = state.page + 1;
      final result = await _fetch(next);
      emit(
        state.copyWith(
          items: [...state.items, ...result.items],
          page: next,
          hasMore: result.hasMore,
          loadingMore: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(loadingMore: false, error: _friendlyError(e)));
    }
  }

  Future<({List<PracticeSessionModel> items, bool hasMore})> _fetch(
    int page,
  ) async {
    final result = await _repository.getPracticeHistory(
      page: page,
      size: pageSize,
      offlineFallback: false,
    );
    final items = (result['items'] as List).cast<PracticeSessionModel>();
    final pages = (result['pages'] as num?)?.toInt() ?? 1;
    return (items: items, hasMore: page < pages);
  }

  String _friendlyError(Object e) {
    if (isConnectionError(e)) return offlineMessage;
    if (e is DioException) return 'Error de conexión con el servidor';
    return e.toString().replaceFirst('Exception: ', '');
  }
}
