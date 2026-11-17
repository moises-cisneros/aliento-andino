import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../connectivity/connectivity_service.dart';
import '../database/app_database.dart';
import '../network/api_client.dart';

/// Vacía el outbox de prácticas (Drift) contra el backend cuando hay conexión.
///
/// Idempotente: cada práctica lleva un `client_id` (UUID) y el backend ignora
/// duplicados, así que reintentar un envío ya aplicado no crea sesiones dobles.
class PracticeSyncService {
  final AppDatabase _db;
  final ApiClient _apiClient;
  final ConnectivityService _connectivity;

  StreamSubscription<bool>? _sub;
  bool _syncing = false;

  PracticeSyncService({
    required AppDatabase db,
    required ApiClient apiClient,
    required ConnectivityService connectivity,
  }) : _db = db,
       _apiClient = apiClient,
       _connectivity = connectivity;

  /// Escucha la conectividad: cada vez que vuelve internet, sincroniza.
  void start() {
    _sub ??= _connectivity.onStatusChange.listen((online) {
      if (online) syncPending();
    });
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }

  /// Envía todas las prácticas en cola. Devuelve cuántas se sincronizaron.
  Future<int> syncPending() async {
    if (_syncing) return 0; // evita corridas concurrentes
    _syncing = true;
    var synced = 0;
    try {
      final pending = await _db.getPendingPractices();
      for (final p in pending) {
        try {
          await _apiClient.dio.post(
            '/practice/submit',
            data: {
              'client_id': p.clientId,
              'lesson_id': p.lessonId,
              'score': p.score,
              'correct_notes': p.correctNotes,
              'total_notes': p.totalNotes,
              'wrong_notes': p.wrongNotes,
              'missed_notes': p.missedNotes,
              'average_tempo': p.averageTempo,
              'total_time_seconds': p.totalTimeSeconds,
              'errors_detail': p.errorsDetailJson == null
                  ? null
                  : jsonDecode(p.errorsDetailJson!),
              'completed': p.completed,
            },
          );
          await _db.deletePending(p.localId);
          synced++;
        } on DioException catch (e) {
          final status = e.response?.statusCode;
          if (status != null && status >= 400 && status < 500) {
            // El server rechazó el item (inválido/duplicado): lo descartamos
            // para que no bloquee la cola (poison-pill).
            debugPrint(
              'Sync: descartando práctica ${p.clientId} (HTTP $status)',
            );
            await _db.deletePending(p.localId);
            continue;
          }
          // Error de red o 5xx: cortamos y reintentamos en la próxima conexión.
          debugPrint('Sync: corte por error transitorio: ${e.message}');
          break;
        }
      }
    } finally {
      _syncing = false;
    }
    return synced;
  }
}
