import 'package:shared_preferences/shared_preferences.dart';

/// Almacenamiento local de estado del onboarding (flag y skill_level temporal).
class OnboardingStorage {
  static const String _completedKey = 'onboarding_completed';
  static const String _skillLevelKey = 'onboarding_skill_level';

  final SharedPreferences _prefs;

  OnboardingStorage(this._prefs);

  /// `true` si el usuario ya pasó por el onboarding al menos una vez.
  bool get isCompleted => _prefs.getBool(_completedKey) ?? false;

  Future<void> markCompleted() async {
    await _prefs.setBool(_completedKey, true);
  }

  /// Nivel auto-declarado durante el cuestionario (se enviará al registrar).
  String? get savedSkillLevel => _prefs.getString(_skillLevelKey);

  Future<void> saveSkillLevel(String level) async {
    await _prefs.setString(_skillLevelKey, level);
  }

  Future<void> clearSkillLevel() async {
    await _prefs.remove(_skillLevelKey);
  }

  /// Resetear todo el onboarding (útil para testing/debug).
  Future<void> reset() async {
    await _prefs.remove(_completedKey);
    await _prefs.remove(_skillLevelKey);
  }
}
