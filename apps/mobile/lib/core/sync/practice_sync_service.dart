import 'dart:async';

import '../../features/practice/data/repositories/practice_repository.dart';
import '../connectivity/connectivity_service.dart';
import '../database/app_database.dart';
import '../network/api_client.dart';

/// Vacía el outbox de prácticas (Drift) contra el backend cuando hay conexión.
///
/// Envía a `POST /api/v1/practice/session`. Idempotente: cada práctica lleva un
/// `client_id` (UUID) y el backend ignora duplicados, así que reintentar un
/// envío ya aplicado no crea sesiones dobles.
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
    try {
      return await PracticeSessionRepository(
        dio: _apiClient.dio,
        db: _db,
      ).syncPending();
    } finally {
      _syncing = false;
    }
  }
}
