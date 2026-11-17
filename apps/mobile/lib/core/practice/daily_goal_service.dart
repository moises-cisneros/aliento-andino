import 'package:shared_preferences/shared_preferences.dart';

/// Meta diaria de práctica (en minutos), persistida localmente. Acumula el
/// tiempo practicado HOY en SEGUNDOS (fuente de verdad, para no perder los
/// restos al redondear); se reinicia solo al cambiar el día. Sin servidor.
class DailyGoalService {
  static const _goalKey = 'daily_goal_minutes';
  static const _dateKey = 'daily_goal_date';
  static const _secondsKey = 'daily_goal_today_seconds';
  static const int defaultGoal = 15;

  String _today() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  Future<int> getGoalMinutes() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_goalKey) ?? defaultGoal;
  }

  Future<void> setGoalMinutes(int minutes) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_goalKey, minutes);
  }

  int _todaySeconds(SharedPreferences p) {
    if (p.getString(_dateKey) != _today()) return 0;
    return p.getInt(_secondsKey) ?? 0;
  }

  /// Minutos practicados hoy (0 si el último registro es de otro día).
  Future<int> getTodayMinutes() async {
    final p = await SharedPreferences.getInstance();
    return _todaySeconds(p) ~/ 60;
  }

  /// Suma minutos (se guardan como segundos) y devuelve el total de minutos.
  Future<int> addMinutes(double minutes) => addSeconds((minutes * 60).round());

  /// Suma segundos al total de hoy y devuelve el nuevo total en minutos. Al
  /// acumular segundos no se pierde el resto entre sesiones cortas.
  Future<int> addSeconds(int seconds) async {
    if (seconds <= 0) return getTodayMinutes();
    final p = await SharedPreferences.getInstance();
    final today = _today();
    var current = 0;
    if (p.getString(_dateKey) == today) {
      current = p.getInt(_secondsKey) ?? 0;
    } else {
      await p.setString(_dateKey, today);
    }
    final updated = current + seconds;
    await p.setInt(_secondsKey, updated);
    return updated ~/ 60;
  }
}
