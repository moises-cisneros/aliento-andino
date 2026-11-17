import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';

import '../../../../core/database/app_database.dart';
import '../models/practice_session_model.dart';

/// Result of [PracticeSessionRepository.submit].
class PracticeSubmitOutcome {
  /// `true` when there was no connection and the session was queued locally.
  final bool pending;

  /// Raw backend response body (`null` when [pending]).
  final Map<String, dynamic>? response;

  const PracticeSubmitOutcome({required this.pending, this.response});
}

/// Sends practice sessions to `POST /api/v1/practice/session`.
///
/// Offline sessions are stored in the local Drift outbox with
/// `is_synced = false` and re-sent later with the same `client_id`, which the
/// backend uses to deduplicate retries.
class PracticeSessionRepository {
  static const endpoint = '/v1/practice/session';

  final Dio _dio;
  final AppDatabase _db;

  const PracticeSessionRepository({required Dio dio, required AppDatabase db})
    : _dio = dio,
      _db = db;

  /// Sends [session]. With no connection it is queued and reported as pending;
  /// a server response (4xx/5xx) is a real error and is propagated.
  Future<PracticeSubmitOutcome> submit(PracticeSessionModel session) async {
    try {
      final response = await _dio.post(endpoint, data: session.toJson());
      return PracticeSubmitOutcome(
        pending: false,
        response: response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : null,
      );
    } on DioException catch (e) {
      if (e.response != null) rethrow;
      await _db.enqueuePractice(
        PendingPracticeCompanion.insert(
          clientId: session.clientId,
          lessonId: session.lessonId,
          score: session.score,
          correctNotes: session.correctNotes,
          totalNotes: session.totalNotes,
          wrongNotes: session.wrongNotes,
          missedNotes: session.missedNotes,
          averageTempo: session.averageTempo,
          totalTimeSeconds: session.totalTimeSeconds,
          errorsDetailJson: Value(
            session.errorsDetail == null
                ? null
                : jsonEncode(session.errorsDetail),
          ),
          completed: Value(session.completed),
        ),
      );
      return const PracticeSubmitOutcome(pending: true);
    }
  }

  /// Sends every queued session. Returns how many were accepted.
  ///
  /// - 2xx: marked `is_synced = true`.
  /// - 4xx other than 404/405/408/429: the server rejected the item for good,
  ///   so it is discarded to avoid blocking the queue.
  /// - Network error, 5xx, 404/405 (endpoint not deployed yet), 408, 429:
  ///   transient, the queue stops and is retried on the next connection.
  Future<int> syncPending() async {
    var synced = 0;
    final pending = await _db.getPendingPractices();
    for (final row in pending) {
      try {
        await _dio.post(endpoint, data: _toSession(row).toJson());
        await _db.markPracticeSynced(row.localId);
        synced++;
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        if (status != null && _isPermanentRejection(status)) {
          debugPrint(
            'Sync: discarding practice ${row.clientId} (HTTP $status)',
          );
          await _db.deletePending(row.localId);
          continue;
        }
        debugPrint('Sync: stopped on transient error: ${e.message}');
        break;
      }
    }
    return synced;
  }

  static bool _isPermanentRejection(int status) =>
      status >= 400 &&
      status < 500 &&
      !const {404, 405, 408, 429}.contains(status);

  static PracticeSessionModel _toSession(PendingPracticeRow row) =>
      PracticeSessionModel(
        lessonId: row.lessonId,
        clientId: row.clientId,
        score: row.score,
        correctNotes: row.correctNotes,
        totalNotes: row.totalNotes,
        wrongNotes: row.wrongNotes,
        missedNotes: row.missedNotes,
        averageTempo: row.averageTempo,
        totalTimeSeconds: row.totalTimeSeconds,
        errorsDetail: row.errorsDetailJson == null
            ? null
            : (jsonDecode(row.errorsDetailJson!) as List<dynamic>)
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .toList(),
        completed: row.completed,
      );
}
