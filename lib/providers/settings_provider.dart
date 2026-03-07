import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

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
  final NotificationPreferences notificationPreferences;   //

  const SettingsState({
    this.selectedThemeIndex = 0,
    this.notificationPreferences = const NotificationPreferences(), //
  });
  bool get notificationsEnabled => notificationPreferences.enabled;

  SettingsState copyWith({
    int? selectedThemeIndex,
    NotificationPreferences? notificationPreferences, //
  }) {
    return SettingsState(
      selectedThemeIndex: selectedThemeIndex ?? this.selectedThemeIndex,
      notificationPreferences:
          notificationPreferences ?? this.notificationPreferences,  //
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
  static const String _notifEnabledKey = 'notifications_enabled';  //
  static const String _notifAllCategoriesKey = 'notifications_all_categories'; //
  static const String _notifCategoriesKey = 'notifications_categories';   //

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeIndex = prefs.getInt(_themeKey) ?? 0;
      final notifEnabled = prefs.getBool(_notifEnabledKey) ?? true;
      final notifAllCategories =
          prefs.getBool(_notifAllCategoriesKey) ?? true;
      final rawCategories =
          prefs.getStringList(_notifCategoriesKey) ?? [];
      final selectedCategories = rawCategories
          .map((s) => NotificationCategoryExtension.fromString(s))
          .toSet();
      

      state = SettingsState(
        selectedThemeIndex: themeIndex,
        notificationPreferences: NotificationPreferences(
          enabled: notifEnabled,
          allCategories: notifAllCategories,
          selectedCategories: selectedCategories,
        ),
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

// activa / desactiva el switchde notificaciones
   Future<void> setNotificationsEnabled(bool enabled,
      {String? userId}) async {
    try {
      final updated =
          state.notificationPreferences.copyWith(enabled: enabled);
      await _persistPrefs(updated);
      state = state.copyWith(notificationPreferences: updated);
      if (userId != null) {
        await saveNotificationPrefsToFirestore(userId, updated);
      }
    } catch (e) {
      'Error saving notifications enabled: $e';
    }
  }
 
 // cambia entre todas las categorias y categorias especificas
  Future<void> setAllCategories(bool allCategories,
      {String? userId}) async {
    try {
      final updated =
          state.notificationPreferences.copyWith(allCategories: allCategories);
      await _persistPrefs(updated);
      state = state.copyWith(notificationPreferences: updated);
      if (userId != null) {
        await saveNotificationPrefsToFirestore(userId, updated);
      }
    } catch (e) {
      'Error saving allCategories: $e';
    }
  }

 // alterna una categoria especifica
  Future<void> toggleCategory(NotificationCategory category,
      {String? userId}) async {
    try {
      final current =
          Set<NotificationCategory>.from(
              state.notificationPreferences.selectedCategories);
      if (current.contains(category)) {
        current.remove(category);
      } else {
        current.add(category);
      }
      final updated = state.notificationPreferences
          .copyWith(selectedCategories: current);
      await _persistPrefs(updated);
      state = state.copyWith(notificationPreferences: updated);
      if (userId != null) {
        await saveNotificationPrefsToFirestore(userId, updated);
      }
    } catch (e) {
      'Error toggling category: $e';
    }
  }

  // carga las preferencias desde Firestore
  Future<void> loadNotificationPrefsFromFirestore(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (!doc.exists) return;
      final data = doc.data() as Map<String, dynamic>;
      final prefs = NotificationPreferences.fromMap(
        data['notificationPreferences'] as Map<String, dynamic>?,
      );
      // Persistir localmente también
      await _persistPrefs(prefs);
      state = state.copyWith(notificationPreferences: prefs);
    } catch (e) {
      'Error loading prefs from Firestore: $e';
    }
  }

 // guarda las preferencias en Firestore
 Future<void> saveNotificationPrefsToFirestore(
      String userId, NotificationPreferences prefs) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'notificationPreferences': prefs.toMap()});
    } catch (e) {
      'Error saving prefs to Firestore (will retry on reconnect): $e';
    }
  }

 // guarda la tres clves de notificación 
  Future<void> _persistPrefs(NotificationPreferences prefs) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_notifEnabledKey, prefs.enabled);
    await sp.setBool(_notifAllCategoriesKey, prefs.allCategories);
    await sp.setStringList(
      _notifCategoriesKey,
      prefs.selectedCategories.map((c) => c.value).toList(),
    );
  }

  Future<void> setNotificationsEnabledSimple(bool enabled) async {
    await setNotificationsEnabled(enabled);
  }

  Future<void> resetSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_themeKey);
      await prefs.remove(_notifEnabledKey);   //
      await prefs.remove(_notifAllCategoriesKey);  //
      await prefs.remove(_notifCategoriesKey);   //

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