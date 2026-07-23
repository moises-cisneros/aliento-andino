import 'package:shared_preferences/shared_preferences.dart';

/// Persiste si el usuario ya vio la leyenda de la barra de herramientas de la
/// pantalla de práctica. La ayuda se auto-muestra una sola vez (la primera vez
/// que se entra a practicar); después queda disponible bajo el botón "?".
class PracticeHelpService {
  static const _seenToolbarKey = 'seen_practice_toolbar_help';

  /// `true` si ya se mostró la leyenda de íconos al usuario.
  Future<bool> hasSeenToolbarHelp() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_seenToolbarKey) ?? false;
  }

  /// Marca la leyenda como vista (se llama al mostrarla por primera vez).
  Future<void> markToolbarHelpSeen() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_seenToolbarKey, true);
  }
}
