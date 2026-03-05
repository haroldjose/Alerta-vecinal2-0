import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/colors.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/active_users_provider.dart';
import '../../providers/settings_provider.dart';
import '../auth/register_screen.dart';

// ─── NUEVO PROVIDER ──────────────────────────────────────────────────────────
// Obtiene todos los usuarios de Firestore con su rol, nombre, username y estado
final allUsersProvider = StreamProvider.autoDispose<List<DirectoryUser>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) {
            try {
              return DirectoryUser.fromFirestore(doc);
            } catch (_) {
              return null;
            }
          })
          .whereType<DirectoryUser>()
          .toList());
});

// ─── MODELO AUXILIAR ─────────────────────────────────────────────────────────
// Combina datos de UserModel con el estado online de ActiveUser
class DirectoryUser {
  final String id;
  final String name;
  final String username;
  final String email;
  final UserRole role;
  final DateTime createdAt;
  final DateTime? lastActive;

  DirectoryUser({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.role,
    required this.createdAt,
    this.lastActive,
  });

  factory DirectoryUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final lastActive = (data['lastActive'] as Timestamp?)?.toDate();

    return DirectoryUser(
      id: doc.id,
      name: data['name'] ?? '',
      username: data['username'] ?? '',
      email: data['email'] ?? '',
      role: UserModel.parseRole(data['role']),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastActive: lastActive,
    );
  }

  // Un usuario se considera online si su lastActive fue hace menos de 2 minutos
  bool get isOnline {
    if (lastActive == null) return false;
    return DateTime.now().difference(lastActive!).inMinutes < 2;
  }

  // Texto de estado formateado
  String get statusText {
    if (isOnline) return 'Online';
    if (lastActive == null) return 'Offline';
    final diff = DateTime.now().difference(lastActive!);
    if (diff.inMinutes < 60) return 'Offline';
    return 'Offline';
  }

  // Fecha de registro formateada (ej: "Oct 12 2023")
  String get registeredText {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return 'Registrado: ${months[createdAt.month - 1]} ${createdAt.day} ${createdAt.year}';
  }
}

// ─── PANTALLA PRINCIPAL ───────────────────────────────────────────────────────
class SecurityHomeScreen extends ConsumerStatefulWidget {
  const SecurityHomeScreen({super.key});

  @override
  ConsumerState<SecurityHomeScreen> createState() => _SecurityHomeScreenState();
}

class _SecurityHomeScreenState extends ConsumerState<SecurityHomeScreen> {
  // Filtro de rol seleccionado: null = Todos
  UserRole? _selectedFilter;

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final allUsers = ref.watch(allUsersProvider);
    final currentTheme = ref.watch(currentThemeProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Directorio de Usuarios',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        // Botón de cerrar sesión solo visible para el usuario seguridad
        actions: [
          currentUser.when(
            data: (user) {
              if (user?.role == UserRole.security) {
                return TextButton(
                  onPressed: _confirmSignOut,
                  child: const Text(
                    'Cerrar Sesion',
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                );
              }
              return const SizedBox();
            },
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
        ],
      ),

      body: Column(
        children: [
          // ─── FILTROS POR ROL ────────────────────────────────────────────
          _buildRoleFilterBar(currentTheme.primary),

          const SizedBox(height: 8),

          // ─── LISTA DE USUARIOS ──────────────────────────────────────────
          Expanded(
            child: allUsers.when(
              data: (users) {
                // Aplicar filtro de rol
                final filtered = _selectedFilter == null
                    ? users
                    : users.where((u) => u.role == _selectedFilter).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No hay usuarios en esta categoría',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(allUsersProvider);
                    await Future.delayed(const Duration(milliseconds: 400));
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      return _buildUserCard(filtered[index]);
                    },
                  ),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (error, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'Error al cargar usuarios',
                      style:
                          TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(allUsersProvider),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      // ─── FAB: Registrar nuevo usuario ────────────────────────────────────
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const RegisterScreen()),
          ).then((_) {
            // Refresca el directorio al volver del registro
            ref.invalidate(allUsersProvider);
          });
        },
        backgroundColor: currentTheme.primary,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }

  // ─── BARRA DE FILTROS ─────────────────────────────────────────────────────
  Widget _buildRoleFilterBar(Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(
              label: 'Todos',
              isSelected: _selectedFilter == null,
              primaryColor: primaryColor,
              onTap: () => setState(() => _selectedFilter = null),
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: 'Admin',
              isSelected: _selectedFilter == UserRole.admin,
              primaryColor: primaryColor,
              onTap: () => setState(() => _selectedFilter = UserRole.admin),
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: 'Vecinos',
              isSelected: _selectedFilter == UserRole.vecino,
              primaryColor: primaryColor,
              onTap: () => setState(() => _selectedFilter = UserRole.vecino),
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: 'Seguridad',
              isSelected: _selectedFilter == UserRole.security,
              primaryColor: primaryColor,
              onTap: () =>
                  setState(() => _selectedFilter = UserRole.security),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required Color primaryColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight:
                isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // ─── TARJETA DE USUARIO ───────────────────────────────────────────────────
  Widget _buildUserCard(DirectoryUser user) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        leading: Stack(
          children: [
            // Avatar con inicial del nombre
            CircleAvatar(
              radius: 26,
              backgroundColor: _roleColor(user.role).withValues(alpha: 0.15),
              child: Text(
                user.name.isNotEmpty
                    ? user.name[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  color: _roleColor(user.role),
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
            // Indicador online/offline
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: user.isOnline ? Colors.green : Colors.grey[400],
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          // Muestra username si existe, sino el nombre
          user.username.isNotEmpty ? user.username : user.name,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          user.registeredText,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Badge de rol
            _buildRoleBadge(user.role),
            const SizedBox(height: 4),
            // Estado online/offline
            Text(
              user.isOnline ? 'Online' : 'Offline',
              style: TextStyle(
                color: user.isOnline ? Colors.green : Colors.grey[400],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── BADGE DE ROL ─────────────────────────────────────────────────────────
  Widget _buildRoleBadge(UserRole role) {
    String label;
    Color bgColor;

    switch (role) {
      case UserRole.admin:
        label = 'ADMIN';
        bgColor = AppColors.primary;
        break;
      case UserRole.security:
        label = 'SEGURIDAD';
        bgColor = Colors.black87;
        break;
      case UserRole.vecino:
        label = 'VECINO';
        bgColor = Colors.transparent;
        break;
    }

    // Vecino no tiene badge de fondo, solo texto de color primario
    if (role == UserRole.vecino) {
      return Text(
        'VECINO',
        style: TextStyle(
          color: AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // Color del avatar según rol
  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return AppColors.primary;
      case UserRole.security:
        return Colors.black87;
      case UserRole.vecino:
        return Colors.teal;
    }
  }

  // ─── CONFIRMAR CIERRE DE SESIÓN ───────────────────────────────────────────
  Future<void> _confirmSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content:
            const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.error),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final authService = ref.read(authServiceProvider);
      await authService.signOut();
    }
  }
}