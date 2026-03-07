import 'package:alerta_vecinal/core/services/sync_service.dart';
import 'package:alerta_vecinal/providers/reports_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../../core/constants/colors.dart';
import '../../core/services/local_storage_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/active_users_provider.dart';
import '../../models/user_model.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Timer? _connectivityCheckTimer;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(connectivityServiceProvider).checkConnectionManually();
    });

    _connectivityCheckTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        ref.read(connectivityServiceProvider).checkConnectionManually().then((_) {
          if (mounted) setState(() {});
        });
      }
    });
  }

  @override
  void dispose() {
    _connectivityCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final settings = ref.watch(settingsProvider);
    final currentTheme = ref.watch(currentThemeProvider);
    
    // conectividad directamente del servicio
    final connectivity = ref.watch(connectivityServiceProvider);
    final isConnected = connectivity.hasConnection;
    
    final syncStatus = ref.watch(syncStatusProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Configuración'),
        backgroundColor: currentTheme.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await ref.read(connectivityServiceProvider).checkConnectionManually();
              setState(() {}); 
            },
            tooltip: 'Actualizar estado de conexión',
          ),
        ],
      ),
      body: currentUser.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('No hay usuario autenticado'));
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Estado de conexión
                _buildConnectionStatus(isConnected, syncStatus, currentTheme),

                const SizedBox(height: 8),

                // Sección: Apariencia
                _buildSectionTitle('Apariencia'),
                _buildThemeSelector(currentTheme, settings.selectedThemeIndex),

                const SizedBox(height: 24),

                // Sección: Notificaciones
                if (user.role == UserRole.vecino ||
                    user.role == UserRole.admin) ...[
                  _buildSectionTitle('Notificaciones'),
                  _buildNotificationSettings(
                    settings.notificationPreferences,
                    currentTheme,
                    user.id,
                  ),
                  const SizedBox(height: 24),
                ],

                // Sección: Usuarios Activos 
                if (user.role == UserRole.admin) ...[
                  _buildSectionTitle('Usuarios Activos'),
                  _buildActiveUsersList(currentTheme),
                  const SizedBox(height: 24),
                ],

                _buildSectionTitle('Información'),
                _buildInfoSection(user, currentTheme),

                const SizedBox(height: 24),

                _buildResetButton(currentTheme, user.id),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error: $error', style: const TextStyle(color: AppColors.error)),
        ),
      ),
    );
  }

  // Estado de conexión directo
  Widget _buildConnectionStatus(
    bool isConnected,
    AsyncValue<SyncStatus> syncStatus,
    AppTheme theme,
  ) {
    final localStorage = LocalStorageService();
    final pendingOps = localStorage.getPendingOperations();
    final hasPendingOps = pendingOps.isNotEmpty;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConnected ? AppColors.success : AppColors.error,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Estado principal
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isConnected
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isConnected ? Icons.wifi : Icons.wifi_off,
                    color: isConnected ? AppColors.success : AppColors.error,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isConnected ? 'En línea' : 'Modo offline',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isConnected ? AppColors.success : AppColors.error,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isConnected
                            ? 'Sincronización activa'
                            : 'Datos guardados localmente',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isConnected
                        ? AppColors.success.withValues(alpha: 0.2)
                        : AppColors.error.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isConnected ? Icons.check_circle : Icons.offline_bolt,
                    color: isConnected ? AppColors.success : AppColors.error,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),

          // Información adicional si hay operaciones pendientes
          if (hasPendingOps) ...[
            const Divider(height: 1, color: AppColors.border),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.sync_problem,
                      color: Colors.orange,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${pendingOps.length} ${pendingOps.length == 1 ? 'operación' : 'operaciones'} pendiente${pendingOps.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isConnected
                              ? 'Sincronizando automáticamente...'
                              : 'Se sincronizarán al conectarse',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isConnected)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                      ),
                    ),
                ],
              ),
            ),
          ],

          // Estado de sincronización
          if (isConnected && !hasPendingOps)
            syncStatus.when(
              data: (status) {
                if (status == SyncStatus.syncing) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.primary.withValues(alpha: 0.05),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(10),
                        bottomRight: Radius.circular(10),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(theme.primary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Sincronizando datos...',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                if (status == SyncStatus.synced) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.05),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(10),
                        bottomRight: Radius.circular(10),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 14,
                          color: AppColors.success,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Datos sincronizados',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.success,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                return const SizedBox.shrink();
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }

  // Selector de tema
  Widget _buildThemeSelector(AppTheme currentTheme, int selectedIndex) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: currentTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.palette,
                    color: currentTheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Color del tema',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Personaliza la apariencia',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5,
              ),
              itemCount: AppTheme.themes.length,
              itemBuilder: (context, index) {
                final theme = AppTheme.themes[index];
                final isSelected = index == selectedIndex;

                return GestureDetector(
                  onTap: () {
                    ref.read(settingsProvider.notifier).setTheme(index);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [theme.secondary, theme.accent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: theme.primary.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Text(
                            theme.name.split(' ').first,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (isSelected)
                          const Positioned(
                            top: 6,
                            right: 6,
                            child: Icon(
                              Icons.check_circle,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Configuración de notificaciones
  Widget _buildNotificationSettings(
    NotificationPreferences prefs,
    AppTheme theme,
    String userId,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            value: prefs.enabled,
            onChanged: (value) {
              ref
                  .read(settingsProvider.notifier)
                  .setNotificationsEnabled(value, userId: userId);
            },
            title: const Text('Notificaciones push',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            subtitle: Text(
              prefs.enabled
                  ? 'Recibirás alertas de nuevos reportes'
                  : 'No recibirás alertas de reportes',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                prefs.enabled
                    ? Icons.notifications_active
                    : Icons.notifications_off,
                color: theme.primary,
                size: 24,
              ),
            ),
            activeThumbColor: theme.primary,
          ),

          if (prefs.enabled) ...[
            const Divider(height: 1, color: AppColors.border),

            // Selector todas o específicas
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Recibir notificaciones de:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ),

            //Todas las categorías
            RadioListTile<bool>(
              value: true,
              groupValue: prefs.allCategories,
              onChanged: (value) {
                if (value == null) return;
                ref
                    .read(settingsProvider.notifier)
                    .setAllCategories(value, userId: userId);
              },
              title: const Text('Todas las categorías',
                  style: TextStyle(
                      fontSize: 15, color: AppColors.textPrimary)),
              subtitle: const Text('Recibe alertas de cualquier reporte',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              activeColor: theme.primary,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16),
            ),

            // Categorías específicas
            RadioListTile<bool>(
              value: false,
              groupValue: prefs.allCategories,
              onChanged: (value) {
                if (value == null) return;
                ref
                    .read(settingsProvider.notifier)
                    .setAllCategories(value, userId: userId);
              },
              title: const Text('Categorías específicas',
                  style: TextStyle(
                      fontSize: 15, color: AppColors.textPrimary)),
              subtitle: const Text(
                  'Elige de qué tipos de reporte recibir alertas',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              activeColor: theme.primary,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16),
            ),

            // Checkboxes de categoría
            if (!prefs.allCategories) ...[
              const Divider(height: 1, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Selecciona al menos una categoría',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[500]),
                      ),
                    ),
                  ],
                ),
              ),
              ...NotificationCategory.values.map((category) {
                final isSelected =
                    prefs.selectedCategories.contains(category);
                return CheckboxListTile(
                  value: isSelected,
                  onChanged: (_) {
                    ref
                        .read(settingsProvider.notifier)
                        .toggleCategory(category, userId: userId);
                  },
                  title: Row(
                    children: [
                      Icon(
                        _categoryIcon(category),
                        size: 18,
                        color: isSelected
                            ? theme.primary
                            : Colors.grey[400],
                      ),
                      const SizedBox(width: 10),
                      Text(
                        category.label,
                        style: TextStyle(
                          fontSize: 15,
                          color: isSelected
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  activeColor: theme.primary,
                  checkColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20),
                  dense: true,
                  // Advertencia visual si no hay ninguna seleccionada
                  tileColor: prefs.selectedCategories.isEmpty
                      ? Colors.red.withValues(alpha: 0.03)
                      : null,
                );
              }),
              // Advertencia si no seleccionó ninguna
              if (prefs.selectedCategories.isEmpty)
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 16, color: Colors.orange),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Debes seleccionar al menos una categoría para recibir notificaciones.',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange[800]),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }

  // icono para las categorias
  IconData _categoryIcon(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.inseguridad:
        return Icons.security;
      case NotificationCategory.serviciosBasicos:
        return Icons.build;
      case NotificationCategory.contaminacion:
        return Icons.eco;
      case NotificationCategory.convivencia:
        return Icons.people;
    }
  }



// Lista de usuarios activos
Widget _buildActiveUsersList(AppTheme theme) {
  final activeUsers = ref.watch(activeUsersProvider);
  final connectivity = ref.watch(connectivityServiceProvider);
  final isConnected = connectivity.hasConnection;

  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.people,
                  color: theme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Usuarios en la plataforma',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              
              if (isConnected)
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  color: theme.primary,
                  onPressed: () {
                    ref.invalidate(activeUsersProvider);
                  },
                  tooltip: 'Refrescar usuarios',
                ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
        activeUsers.when(
          data: (users) {
            if (users.isEmpty && isConnected) {
              return Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No hay usuarios registrados',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }

            if (users.isEmpty && !isConnected) {
              return Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.wifi_off,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Sin conexión',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Conéctate para ver usuarios activos',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            final onlineUsers = users.where((u) => u.isOnline).length;
            
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$onlineUsers en línea',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${users.length} total',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: users.length > 10 ? 10 : users.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    color: AppColors.border,
                    indent: 16,
                    endIndent: 16,
                  ),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return ListTile(
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            backgroundColor: theme.primary.withValues(alpha: 0.1),
                            child: Text(
                              user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                              style: TextStyle(
                                color: theme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (user.isOnline)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      title: Text(
                        user.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        user.email,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: Text(
                        user.statusText,
                        style: TextStyle(
                          fontSize: 12,
                          color: user.isOnline ? AppColors.success : AppColors.textSecondary,
                          fontWeight: user.isOnline ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, stack) {
            final isPermissionError = error.toString().contains('permission-denied');
            final isUnavailableError = error.toString().contains('UNAVAILABLE');
            
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    isPermissionError 
                        ? Icons.lock_outline 
                        : isUnavailableError
                            ? Icons.wifi_off
                            : Icons.error_outline,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isPermissionError 
                        ? 'Sin permisos de acceso'
                        : isUnavailableError
                            ? 'Sin conexión al servidor'
                            : 'Error al cargar usuarios',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isPermissionError 
                        ? 'Verifica las reglas de seguridad en Firebase'
                        : isUnavailableError
                            ? 'Verifica tu conexión a internet'
                            : 'Intenta refrescar la pantalla',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () {
                      // Forzar reconexión y refrescar
                      ref.read(connectivityServiceProvider).checkConnectionManually();
                      ref.invalidate(activeUsersProvider);
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Reintentar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.primary,
                      side: BorderSide(color: theme.primary),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    ),
  );
}

  // Sección de información
  Widget _buildInfoSection(UserModel user, AppTheme theme) {
      String roleLabel;
    switch (user.role) {
      case UserRole.admin:
        roleLabel = 'Administrador';
        break;
      case UserRole.security:
        roleLabel = 'Seguridad';
        break;
      case UserRole.vecino:
      default:
        roleLabel = 'Vecino';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.person, color: theme.primary, size: 24),
            ),
            title: const Text(
              'Usuario',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            subtitle: Text(
              user.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.border, indent: 16, endIndent: 16),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.email, color: theme.primary, size: 24),
            ),
            title: const Text(
              'Correo',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            subtitle: Text(
              user.email,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.border, indent: 16, endIndent: 16),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.shield, color: theme.primary, size: 24),
            ),
            title: const Text(
              'Rol',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            subtitle: Text(
              roleLabel,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Botón de restablecer configuración
  Widget _buildResetButton(AppTheme theme, String userId) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Restablecer configuración'),
              content: const Text(
                '¿Estás seguro de que deseas restablecer toda la configuración a los valores predeterminados?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  child: const Text('Restablecer'),
                ),
              ],
            ),
          );

          if (confirm == true) {
            await ref.read(settingsProvider.notifier).resetSettings();
            await ref
                .read(settingsProvider.notifier)
                .saveNotificationPrefsToFirestore(
                  userId,
                  const NotificationPreferences(),
                );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Configuración restablecida'),
                  backgroundColor: AppColors.success,
                ),
              );
            }
          }
        },
        icon: const Icon(Icons.restore),
        label: const Text('Restablecer configuración'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: const BorderSide(color: AppColors.error),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  // Título de sección
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
 
