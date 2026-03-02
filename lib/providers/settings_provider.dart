import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Lista de temas predefinidos
class AppTheme {
  final String name;
  final Color primary;
  final Color secondary;
  final Color accent;

  const AppTheme({
    required this.name,
    required this.primary,
    required this.secondary,
    required this.accent,
  });

  static const List<AppTheme> themes = [
    AppTheme(
      name: 'Azul (Predeterminado)',
      primary: Color(0xFF4353F4),
      secondary: Color(0xFF28318F),
      accent: Color(0xFF4554F5),
    ),
    AppTheme(
      name: 'Verde',
      primary: Color(0xFF10B981),
      secondary: Color(0xFF059669),
      accent: Color(0xFF34D399),
    ),
    AppTheme(
      name: 'Morado',
      primary: Color(0xFF8B5CF6),
      secondary: Color(0xFF7C3AED),
      accent: Color(0xFFA78BFA),
    ),
    AppTheme(
      name: 'Naranja',
      primary: Color(0xFFF97316),
      secondary: Color(0xFFEA580C),
      accent: Color(0xFFFB923C),
    ),
    AppTheme(
      name: 'Rosa',
      primary: Color(0xFFEC4899),
      secondary: Color(0xFFDB2777),
      accent: Color(0xFFF472B6),
    ),
    AppTheme(
      name: 'Índigo',
      primary: Color(0xFF6366F1),
      secondary: Color(0xFF4F46E5),
      accent: Color(0xFF818CF8),
    ),
  ];
}

// Estado de configuración
class SettingsState {
  final int selectedThemeIndex;
  final bool notificationsEnabled;

  const SettingsState({
    this.selectedThemeIndex = 0,
    this.notificationsEnabled = true,
  });

  SettingsState copyWith({
    int? selectedThemeIndex,
    bool? notificationsEnabled,
  }) {
    return SettingsState(
      selectedThemeIndex: selectedThemeIndex ?? this.selectedThemeIndex,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }

  AppTheme get currentTheme => AppTheme.themes[selectedThemeIndex];
}

// Provider de configuración
class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState()) {
    _loadSettings();
  }

  static const String _themeKey = 'selected_theme_index';
  static const String _notificationsKey = 'notifications_enabled';

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeIndex = prefs.getInt(_themeKey) ?? 0;
      final notificationsEnabled = prefs.getBool(_notificationsKey) ?? true;

      state = SettingsState(
        selectedThemeIndex: themeIndex,
        notificationsEnabled: notificationsEnabled,
      );
    } catch (e) {
      'Error loading settings: $e';
    }
  }

  Future<void> setTheme(int themeIndex) async {
    if (themeIndex < 0 || themeIndex >= AppTheme.themes.length) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themeKey, themeIndex);
      state = state.copyWith(selectedThemeIndex: themeIndex);
    } catch (e) {
      'Error saving theme: $e';
    }
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_notificationsKey, enabled);
      state = state.copyWith(notificationsEnabled: enabled);
    } catch (e) {
      'Error saving notifications setting: $e';
    }
  }

  Future<void> resetSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_themeKey);
      await prefs.remove(_notificationsKey);
      state = const SettingsState();
    } catch (e) {
      'Error resetting settings: $e';
    }
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});

// Provider del tema actual
final currentThemeProvider = Provider<AppTheme>((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.currentTheme;
});