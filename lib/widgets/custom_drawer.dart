import 'dart:io';
import 'package:alerta_vecinal/core/constants/colors.dart';
import 'package:alerta_vecinal/models/user_model.dart';
import 'package:alerta_vecinal/providers/auth_provider.dart';
import 'package:alerta_vecinal/providers/user_provider.dart';
import 'package:alerta_vecinal/providers/reports_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/report_model.dart';
import '../screens/problems/problem_type_screen.dart';
import '../screens/reports/my_reports_screen.dart';
import 'package:image_picker/image_picker.dart';

import '../screens/settings/settings_screen.dart';
import '../providers/settings_provider.dart';

class CustomDrawer extends ConsumerStatefulWidget {
  const CustomDrawer({super.key});

  @override
  ConsumerState<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends ConsumerState<CustomDrawer> {
  Future<void> _changeProfileImage(UserModel user) async {
  
    try {

      // Usar ImagePicker directamente en lugar del servicio
      final ImageSource? source = await showDialog<ImageSource?>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Seleccionar imagen'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Galería'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Cámara'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ],
          );
        },
      );

      if (source != null) {
        final ImagePicker picker = ImagePicker();

        await Future.delayed(const Duration(milliseconds: 500));


        final XFile? image = await picker.pickImage(
          source: source,
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 85,
          preferredCameraDevice: CameraDevice.rear,
        );

        if (image != null) {
          final File imageFile = File(image.path);

          if (await imageFile.exists()) {
            final fileSize = await imageFile.length();

            if (fileSize > 0) {
              // Subir imagen usando el provider
              await ref
                  .read(profileImageProvider.notifier)
                  .uploadProfileImage(imageFile, user.id);

              ref.invalidate(currentUserProvider);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Imagen actualizada correctamente'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            } else {
              throw 'El archivo seleccionado está vacío';
            }
          } else {
            throw 'No se pudo acceder al archivo seleccionado';
          }
        } else {
          'No se seleccionó ninguna imagen del picker';
        }
      } else {
        'No se seleccionó ninguna fuente';
      }
    } catch (e, stackTrace) {
      'Error en _changeProfileImage: $e, StackTrace: $stackTrace';

      if (mounted) {
        String errorMessage = 'Error desconocido';

        if (e.toString().contains('camera_access_denied')) {
          errorMessage = 'Permisos de cámara denegados';
        } else if (e.toString().contains('photo_access_denied')) {
          errorMessage = 'Permisos de galería denegados';
        } else if (e.toString().contains('empty')) {
          errorMessage = 'El archivo seleccionado está vacío';
        } else {
          errorMessage = 'Error: $e';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _navigateToProblemType(String problemType) {
    Navigator.pop(context);

    ProblemType type;
    switch (problemType) {
      case 'Inseguridad':
        type = ProblemType.inseguridad;
        break;
      case 'Servicios Básicos':
        type = ProblemType.serviciosBasicos;
        break;
      case 'Contaminación':
        type = ProblemType.contaminacion;
        break;
      case 'Convivencia':
        type = ProblemType.convivencia;
        break;
      default:
        type = ProblemType.inseguridad;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProblemTypeScreen(problemType: type),
      ),
    );
  }

  void _navigateToMyReports() {
    Navigator.pop(context); 
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MyReportsScreen()),
    );
  }

  Future<void> _signOut() async {
    final authService = ref.read(authServiceProvider);
    await authService.signOut();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final profileImageState = ref.watch(profileImageProvider);
    final myReportsCount = ref.watch(myReportsCountProvider);
    final currentTheme = ref.watch(currentThemeProvider);

    // Escuchar cambios en el estado de subida de imagen
    ref.listen<AsyncValue<String?>>(profileImageProvider, (previous, next) {
      next.when(
        data: (imageUrl) {
          if (previous?.isLoading == true && imageUrl != null) {
            ref.invalidate(currentUserProvider);
          }
        },
        loading: () {},
        error: (error, stack) {},
      );
    });

    return Drawer(
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          // Header del drawer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 60, 16, 20),
            decoration: BoxDecoration(color: currentTheme.primary),
            child: currentUser.when(
              data: (user) {
                if (user == null) return const SizedBox();

                return Column(
                  children: [
                    // Círculo para foto de perfil
                    Stack(
                      children: [
                        GestureDetector(
                          onTap: () => _changeProfileImage(user),
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.background,
                                width: 3,
                              ),
                              color: AppColors.background,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(50),
                              child:
                                  user.profileImage != null &&
                                          user.profileImage!.isNotEmpty
                                      ? Image.network(
                                        user.profileImage!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (
                                          context,
                                          error,
                                          stackTrace,
                                        ) {
                                          return _buildDefaultAvatar();
                                        },
                                        loadingBuilder: (
                                          context,
                                          child,
                                          loadingProgress,
                                        ) {
                                          if (loadingProgress == null) {
                                            return child;
                                          }
                                          return const Center(
                                            child: CircularProgressIndicator(
                                              color: AppColors.primary,
                                              strokeWidth: 2,
                                            ),
                                          );
                                        },
                                      )
                                      : _buildDefaultAvatar(),
                            ),
                          ),
                        ),

                        // Indicador de carga si se está subiendo imagen
                        if (profileImageState.isLoading)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black54,
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.background,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ),

                        // Ícono de cámara
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.accent,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: AppColors.background,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Texto de bienvenida
                    Text(
                      'Bienvenido ${user.name}',
                      style: const TextStyle(
                        color: AppColors.background,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                );
              },
              loading:
                  () => const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.background,
                    ),
                  ),
              error:
                  (error, stack) => const Text(
                    'Error al cargar usuario',
                    style: TextStyle(color: AppColors.background),
                  ),
            ),
          ),

          // Línea separadora
          const Divider(color: AppColors.border, thickness: 1, height: 1),

          // Lista de opciones
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // Mis Reportes
                myReportsCount.when(
                  data:
                      (count) => ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: currentTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child:  Icon(
                            Icons.assignment,
                            color: currentTheme.primary,
                            size: 24,
                          ),
                        ),
                        title: const Text(
                          'Mis Reportes',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '$count ${count == 1 ? 'reporte' : 'reportes'}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (count > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: currentTheme.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  count.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_forward_ios,
                              color: AppColors.textSecondary,
                              size: 16,
                            ),
                          ],
                        ),
                        onTap: _navigateToMyReports,
                      ),
                  loading:
                      () => ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: currentTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child:  Icon(
                            Icons.assignment,
                            color: currentTheme.primary,
                            size: 24,
                          ),
                        ),
                        title: const Text(
                          'Mis Reportes',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: const Text(
                          'Cargando...',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          color: AppColors.textSecondary,
                          size: 16,
                        ),
                        onTap: _navigateToMyReports,
                      ),
                  error:
                      (_, __) => ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: currentTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child:  Icon(
                            Icons.assignment,
                            color: currentTheme.primary,
                            size: 24,
                          ),
                        ),
                        title: const Text(
                          'Mis Reportes',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          color: AppColors.textSecondary,
                          size: 16,
                        ),
                        onTap: _navigateToMyReports,
                      ),
                ),

                const Divider(color: AppColors.border, height: 16),
                //
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: currentTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child:  Icon(
                      Icons.settings,
                      color: currentTheme.primary,
                      size: 24,
                    ),
                  ),
                  title: const Text(
                    'Configuración',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    color: AppColors.textSecondary,
                    size: 16,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
                ),

                const Divider(color: AppColors.border, height: 16),

                // Título de sección
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    'Categorías de Reportes',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                // Tipos de problemas
                _buildProblemTypeItem(
                  icon: Icons.security,
                  title: 'Inseguridad',
                  onTap: () => _navigateToProblemType('Inseguridad'),
                ),

                _buildProblemTypeItem(
                  icon: Icons.build,
                  title: 'Servicios Básicos',
                  onTap: () => _navigateToProblemType('Servicios Básicos'),
                ),

                _buildProblemTypeItem(
                  icon: Icons.eco,
                  title: 'Contaminación',
                  onTap: () => _navigateToProblemType('Contaminación'),
                ),

                _buildProblemTypeItem(
                  icon: Icons.people,
                  title: 'Convivencia',
                  onTap: () => _navigateToProblemType('Convivencia'),
                ),

                const Divider(color: AppColors.border, height: 24),

                // Cerrar sesión
                ListTile(
                  leading: const Icon(Icons.logout, color: AppColors.error),
                  title: const Text(
                    'Cerrar Sesión',
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: _signOut,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: 100,
      height: 100,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.border,
      ),
      child: const Icon(Icons.person, color: AppColors.textSecondary, size: 50),
    );
  }

  Widget _buildProblemTypeItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final currentTheme = ref.watch(currentThemeProvider);
    return ListTile(
      leading: Icon(icon, color: currentTheme.primary, size: 22),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      trailing: const Icon(
        Icons.arrow_forward_ios,
        color: AppColors.textSecondary,
        size: 14,
      ),
    );
  }
}

