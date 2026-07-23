import 'package:connectivity_plus/connectivity_plus.dart';

/// Wrapper sobre connectivity_plus.
///
/// Nota: connectivity solo indica que hay una interfaz de red activa, no que
/// internet realmente funcione (p. ej. portales cautivos). Para disparar una
/// sincronización alcanza: el intento de sync fallará con gracia si no hay red.
class ConnectivityService {
  final Connectivity _connectivity;

  ConnectivityService([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  Future<bool> get isOnline async {
    final results = await _connectivity.checkConnectivity();
    return _online(results);
  }

  /// Emite `true` al recuperar conexión y `false` al perderla.
  Stream<bool> get onStatusChange =>
      _connectivity.onConnectivityChanged.map(_online);

  /// Igual que [onStatusChange] pero emite primero el estado ACTUAL (útil para
  /// widgets que reaccionan también al estado inicial, como el banner offline).
  Stream<bool> get statusStream async* {
    yield await isOnline;
    yield* onStatusChange;
  }

  bool _online(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);
}
