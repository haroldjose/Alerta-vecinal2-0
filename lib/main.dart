import 'package:alerta_vecinal/providers/active_users_provider.dart';
import 'package:alerta_vecinal/providers/auth_provider.dart';
import 'package:alerta_vecinal/providers/settings_provider.dart';
import 'package:alerta_vecinal/screens/auth/login_screen.dart';
import 'package:alerta_vecinal/screens/home/home_screen.dart';
import 'package:alerta_vecinal/core/constants/colors.dart';
import 'package:alerta_vecinal/core/services/notification_service.dart';
import 'package:alerta_vecinal/core/services/local_storage_service.dart';
import 'package:alerta_vecinal/core/services/connectivity_service.dart';
import 'package:alerta_vecinal/core/services/sync_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Inicializar Firebase
  await Firebase.initializeApp();

  // Configurar Firestore para modo offline (reducir warnings)
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true, 
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // 2. Inicializar servicio de notificaciones
  await NotificationService().initialize();

  // 3. Inicializar almacenamiento local (Hive)
  await LocalStorageService().initialize();

  // 4. Inicializar servicio de conectividad
  await ConnectivityService().initialize();

  // 5. Inicializar servicio de sincronización
  await SyncService().initialize();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(currentThemeProvider);

    // Guardar token cuando el usuario inicie sesión
    ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) {
      next.whenData((user) {
        if (user != null) {
          // Guardar token FCM del usuario
          NotificationService().saveUserToken(user.uid);

          ref.read(userActivityServiceProvider).startActivityTracking(user.uid);
        }
      });
    });

    return MaterialApp(
      title: 'Alerta Vecinal',
      theme: ThemeData(
        primaryColor: currentTheme.primary,
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: AppBarTheme(
          backgroundColor: currentTheme.primary,
          foregroundColor: AppColors.background,
          elevation: 0,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: currentTheme.primary,
          primary: currentTheme.primary,
          secondary: currentTheme.secondary,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: currentTheme.primary,
        ),
      ),
      home: Consumer(
        builder: (context, ref, child) {
          final authState = ref.watch(authStateProvider);
          return authState.when(
            data:
                (user) =>
                    user != null ? const HomeScreen() : const LoginScreen(),
            loading:
                () => const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
            error: (error, stack) => const LoginScreen(),
          );
        },
      ),
    );
  }
}
