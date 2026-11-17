import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/network/network_error.dart';
import '../../../data/models/ranking_entry_model.dart';
import '../../../data/repositories/ranking_repository.dart';
import 'rankings_event.dart';
import 'rankings_state.dart';

/// BLoC de rankings y leaderboards.
class RankingsBloc extends Bloc<RankingsEvent, RankingsState> {
  final RankingRepository rankingRepository;

  RankingsBloc({required this.rankingRepository}) : super(RankingsInitial()) {
    on<RankingsLoadGlobal>(_onLoadGlobal);
    on<RankingsLoadFriends>(_onLoadFriends);
    on<RankingsLoadWeekly>(_onLoadWeekly);
    on<RankingsLoadStreaks>(_onLoadStreaks);
    on<RankingsLoadMyXP>(_onLoadMyXP);
    on<RankingsLoadLessonRanking>(_onLoadLessonRanking);
  }

  Future<void> _onLoadGlobal(
    RankingsLoadGlobal event,
    Emitter<RankingsState> emit,
  ) async {
    emit(RankingsLoading());
    try {
      final data = await rankingRepository.getGlobalLeaderboard();
      emit(
        RankingsLoaded(
          leaderboard: data['leaderboard'] as List<RankingEntryModel>,
          myRank: data['my_rank'] as int,
          myXP: data['my_xp'] as int,
          myLevel: data['my_level'] as int,
          activeTab: 'global',
        ),
      );
    } catch (e) {
      emit(
        RankingsError(
          message: isConnectionError(e)
              ? offlineMessage
              : 'Error al cargar ranking global',
        ),
      );
    }
  }

  Future<void> _onLoadFriends(
    RankingsLoadFriends event,
    Emitter<RankingsState> emit,
  ) async {
    emit(RankingsLoading());
    try {
      final data = await rankingRepository.getFriendsLeaderboard();
      emit(
        RankingsLoaded(
          leaderboard: data['leaderboard'] as List<RankingEntryModel>,
          myRank: data['my_rank'] as int,
          myXP: data['my_xp'] as int,
          myLevel: data['my_level'] as int,
          activeTab: 'friends',
        ),
      );
    } catch (e) {
      emit(
        RankingsError(
          message: isConnectionError(e)
              ? offlineMessage
              : 'Error al cargar ranking de amigos',
        ),
      );
    }
  }

  Future<void> _onLoadWeekly(
    RankingsLoadWeekly event,
    Emitter<RankingsState> emit,
  ) async {
    emit(RankingsLoading());
    try {
      final data = await rankingRepository.getWeeklyLeaderboard();
      // Convertir a RankingEntryModel (misma estructura)
      final entries = data['leaderboard'] as List<RankingEntryModel>;
      emit(
        RankingsLoaded(
          leaderboard: entries,
          myRank: data['my_rank'] as int,
          myXP: data['my_weekly_xp'] as int,
          daysRemaining: data['days_remaining'] as int,
          activeTab: 'weekly',
        ),
      );
    } catch (e) {
      emit(
        RankingsError(
          message: isConnectionError(e)
              ? offlineMessage
              : 'Error al cargar ranking semanal',
        ),
      );
    }
  }

  Future<void> _onLoadStreaks(
    RankingsLoadStreaks event,
    Emitter<RankingsState> emit,
  ) async {
    emit(RankingsLoading());
    try {
      final data = await rankingRepository.getStreaksLeaderboard();
      // Reutilizar RankingEntryModel con datos de streak
      final entries = data['leaderboard'] as List<RankingEntryModel>;
      emit(
        RankingsLoaded(
          leaderboard: entries,
          myRank: data['my_rank'] as int,
          myXP: data['my_streak'] as int,
          activeTab: 'streaks',
        ),
      );
    } catch (e) {
      emit(
        RankingsError(
          message: isConnectionError(e)
              ? offlineMessage
              : 'Error al cargar ranking de rachas',
        ),
      );
    }
  }

  Future<void> _onLoadMyXP(
    RankingsLoadMyXP event,
    Emitter<RankingsState> emit,
  ) async {
    emit(RankingsLoading());
    try {
      final xpData = await rankingRepository.getMyXP();
      emit(MyXPLoaded(xpData: xpData));
    } catch (e) {
      emit(
        RankingsError(
          message: isConnectionError(e)
              ? offlineMessage
              : 'Error al cargar datos de XP',
        ),
      );
    }
  }

  Future<void> _onLoadLessonRanking(
    RankingsLoadLessonRanking event,
    Emitter<RankingsState> emit,
  ) async {
    emit(RankingsLoading());
    try {
      final data = await rankingRepository.getLessonLeaderboard(event.lessonId);
      emit(
        LessonRankingLoaded(
          leaderboard: data['leaderboard'],
          myBestScore: data['my_best_score'] as double,
          myRank: data['my_rank'] as int,
          lessonTitle: event.lessonTitle,
        ),
      );
    } catch (e) {
      emit(
        RankingsError(
          message: isConnectionError(e)
              ? offlineMessage
              : 'Error al cargar ranking de lección',
        ),
      );
    }
  }
}
