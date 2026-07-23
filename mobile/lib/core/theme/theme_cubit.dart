import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Estado del tema.
class ThemeState extends Equatable {
  final ThemeMode themeMode;
  const ThemeState({required this.themeMode});

  @override
  List<Object> get props => [themeMode];
}

/// Cubit para gestionar el tema (claro / oscuro / sistema).
class ThemeCubit extends Cubit<ThemeState> {
  final SharedPreferences _prefs;
  static const _key = 'theme_mode';

  ThemeCubit(this._prefs) : super(ThemeState(themeMode: _loadInitial(_prefs)));

  static ThemeMode _loadInitial(SharedPreferences prefs) {
    switch (prefs.getString(_key)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  void setThemeMode(ThemeMode mode) {
    _prefs.setString(_key, mode.name);
    emit(ThemeState(themeMode: mode));
  }

  void toggleTheme() {
    final newMode = state.themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    setThemeMode(newMode);
  }
}
