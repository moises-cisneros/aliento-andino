import 'package:flutter/material.dart';

/// Temas claro y oscuro para PianoVision AI.
class AppTheme {
  AppTheme._();

  // Colores semánticos fijos (iguales en ambos temas)
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);
  static const Color orange = Color(0xFFF97316);

  // Medallas
  static const Color gold = Color(0xFFFFD700);
  static const Color silver = Color(0xFFC0C0C0);
  static const Color bronze = Color(0xFFCD7F32);

  // Rareza de logros
  static const Color rarityCommon = Color(0xFF94A3B8);
  static const Color rarityRare = Color(0xFF3B82F6);
  static const Color rarityEpic = Color(0xFF8B5CF6);
  static const Color rarityLegendary = Color(0xFFF59E0B);

  // Texto secundario / muted
  static const Color muted = Color(0xFF64748B);
  static const Color mutedDark = Color(0xFF4B5563);

  // Error fijo (para widgets sin acceso a context)
  static const Color error = Color(0xFFEF4444);

  // Gradientes decorativos (dark mode)
  static const Color gradientDarkCyan = Color(0xFF0E3A4A);
  static const Color gradientDarkGreen = Color(0xFF0A2E1A);

  // Cyan primario (para uso fuera del theme)
  static const Color cyan = Color(0xFF06B6D4);

  // ============ DARK THEME ============
  static ThemeData get darkTheme => _build(
    brightness: Brightness.dark,
    scaffoldBg: const Color(0xFF0A0E17),
    surface: const Color(0xFF111827),
    surfaceHigh: const Color(0xFF1F2937),
    surfaceHighest: const Color(0xFF1A2235),
    primary: const Color(0xFF06B6D4),
    secondary: const Color(0xFF8B5CF6),
    error: const Color(0xFFEF4444),
    onSurface: const Color(0xFFE2E8F0),
    onSurfaceVariant: const Color(0xFF94A3B8),
    outline: const Color(0xFF1E293B),
    outlineVariant: const Color(0xFF374151),
    hint: const Color(0xFF64748B),
    divider: const Color(0xFF374151),
  );

  // ============ LIGHT THEME ============
  static ThemeData get lightTheme => _build(
    brightness: Brightness.light,
    scaffoldBg: const Color(0xFFF5F7FA),
    surface: const Color(0xFFFFFFFF),
    surfaceHigh: const Color(0xFFFFFFFF),
    surfaceHighest: const Color(0xFFEDF2F7),
    primary: const Color(0xFF0891B2),
    secondary: const Color(0xFF7C3AED),
    error: const Color(0xFFDC2626),
    onSurface: const Color(0xFF1A202C),
    onSurfaceVariant: const Color(0xFF4A5568),
    outline: const Color(0xFFE2E8F0),
    outlineVariant: const Color(0xFFCBD5E0),
    hint: const Color(0xFF718096),
    divider: const Color(0xFFE2E8F0),
  );

  // ============ BUILDER ============
  static ThemeData _build({
    required Brightness brightness,
    required Color scaffoldBg,
    required Color surface,
    required Color surfaceHigh,
    required Color surfaceHighest,
    required Color primary,
    required Color secondary,
    required Color error,
    required Color onSurface,
    required Color onSurfaceVariant,
    required Color outline,
    required Color outlineVariant,
    required Color hint,
    required Color divider,
  }) {
    final bool isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: scaffoldBg,
      hintColor: hint,
      dividerColor: divider,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        onPrimary: Colors.white,
        secondary: secondary,
        onSecondary: Colors.white,
        error: error,
        onError: Colors.white,
        surface: surface,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVariant,
        surfaceContainerHigh: surfaceHigh,
        surfaceContainerHighest: surfaceHighest,
        outline: outline,
        outlineVariant: outlineVariant,
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        foregroundColor: onSurface,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
      ),

      // Diálogos
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceHigh,
        titleTextStyle: TextStyle(
          color: onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(color: onSurfaceVariant, fontSize: 14),
      ),

      // Input fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? surfaceHighest : outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: error, width: 2),
        ),
        labelStyle: TextStyle(color: onSurfaceVariant),
        hintStyle: TextStyle(color: hint),
      ),

      // Botones elevados
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      // Botones outlined
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          minimumSize: const Size(double.infinity, 52),
          side: BorderSide(color: outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),

      // Botones de texto
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceHigh,
        contentTextStyle: TextStyle(color: onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),

      // Bottom Navigation
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scaffoldBg,
        selectedItemColor: primary,
        unselectedItemColor: onSurfaceVariant,
      ),

      // Navigation Bar (Material 3)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scaffoldBg,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primary.withValues(alpha: 0.2),
      ),

      // Texto
      textTheme: TextTheme(
        headlineLarge: TextStyle(color: onSurface, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(
          color: onSurface,
          fontWeight: FontWeight.bold,
        ),
        headlineSmall: TextStyle(color: onSurface, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: onSurface),
        bodyMedium: TextStyle(color: onSurfaceVariant),
        bodySmall: TextStyle(color: onSurfaceVariant),
      ),

      // Cards
      cardTheme: CardThemeData(color: surface, elevation: isDark ? 0 : 1),

      // Divider
      dividerTheme: DividerThemeData(color: divider),

      // Progress indicators
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return hint;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary.withValues(alpha: 0.3);
          }
          return outlineVariant;
        }),
      ),
    );
  }
}
