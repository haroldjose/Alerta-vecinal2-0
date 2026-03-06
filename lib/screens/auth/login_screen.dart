import 'package:alerta_vecinal/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/colors.dart';
import '../../core/utils/validators.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../providers/auth_provider.dart';
import '../home/home_screen.dart';
import '../security/security_home_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameController = TextEditingController(); //renombrado
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  String? _usernameError; //
  String? _passwordError;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    
    // Agrega validación en tiempo real
    _usernameController.addListener(_onFieldChanged); //
    _passwordController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Validación en tiempo real
  void _onFieldChanged() {
    setState(() {
      // valida si hay texto en el campo
      _usernameError = _usernameController.text.isNotEmpty   //
          ? Validators.validateUsername(_usernameController.text) 
          : null;
      
      _passwordError = _passwordController.text.isNotEmpty 
          ? Validators.validatePassword(_passwordController.text) 
          : null;
    });
    
  }

  // Validación antes del envío
  void _validateForSubmission() {
    setState(() {
      _usernameError = Validators.validateUsername(_usernameController.text); //
      _passwordError = Validators.validatePassword(_passwordController.text);
    });
  }

  bool get _isFormValid {
    final hasRequiredFields = _usernameController.text.isNotEmpty &&  //
                             _passwordController.text.isNotEmpty;
    
    final hasNoErrors = _usernameError == null && _passwordError == null; //
    
    return hasRequiredFields && hasNoErrors;
  }

  Future<void> _signIn() async {
    _validateForSubmission();
    
    if (!_isFormValid) {
      _showErrorMessage('Por favor, corrige los errores en el formulario');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = ref.read(authServiceProvider);
      
      //el servicio buscará el email asociado a el username en Firestore y luego autenticará con Firebase Auth
      final user = await authService.signInWithUsername(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );

      if (user != null && mounted) {
        _showSuccessMessage('¡Bienvenido de nuevo, ${user.name}!');
        
        await Future.delayed(const Duration(milliseconds: 1000));
        
        if (mounted) {
          _navigateByRole(user);
        }
      } else {
        _showErrorMessage('Error al iniciar sesión. Intenta nuevamente.');
      }
    } on UsernameNotFoundException { //
      if (mounted) {
        _showErrorMessage('El nombre de usuario no existe. Verifica e intenta nuevamente.');
      }
    } on WrongPasswordException {   //
      if (mounted) {
        _showErrorMessage('Contraseña incorrecta. Intenta nuevamente.');
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('Usuario no valido, Intenta nuevamente ');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

// navega a la pantalla correspondiente según el rol
  void _navigateByRole(UserModel user) {
    Widget destination;

    switch (user.role) {
      case UserRole.security:
        destination = const SecurityHomeScreen();
        break;
      case UserRole.admin:
      case UserRole.vecino:
      default:
        destination = const HomeScreen();
        break;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => destination),
    );
  }


  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Alerta Vecinal',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 8),
              
              const Text(
                'Conectando con los vecinos',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
              
              const SizedBox(height: 60),
              
              // Título del formulario
              const Text(
                'Iniciar Sesión',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Formulario
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    
                    CustomTextField(
                      hintText: 'Nombre de usuario', //
                      controller: _usernameController,
                      keyboardType: TextInputType.emailAddress,
                      errorText: _usernameError,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Ej: Juan12  (primer nombre + 2 dígitos de cédula)',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Campo Contraseña
                    CustomTextField(
                      hintText: 'Contraseña',
                      controller: _passwordController,
                      obscureText: true,
                      errorText: _passwordError,
                    ),
                    
                    const SizedBox(height: 40),
                    
                    
                    // Botón Iniciar Sesión
                    CustomButton(
                      text: 'Iniciar Sesión',
                      onPressed: _isFormValid ? _signIn : null,
                      isLoading: _isLoading,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Enlace de registro
                    // Row(
                    //   mainAxisAlignment: MainAxisAlignment.center,
                    //   children: [
                    //     const Text(
                    //       '¿No tienes cuenta? ',
                    //       style: TextStyle(
                    //         color: AppColors.textSecondary,
                    //         fontSize: 14,
                    //       ),
                    //     ),
                    //     GestureDetector(
                    //       onTap: () {
                    //         Navigator.push(
                    //           context,
                    //           MaterialPageRoute(
                    //             builder: (context) => const RegisterScreen(),
                    //           ),
                    //         );
                    //       },
                    //       child: const Text(
                    //         'Registrarse',
                    //         style: TextStyle(
                    //           color: AppColors.primary,
                    //           fontSize: 14,
                    //           fontWeight: FontWeight.w600,
                    //         ),
                    //       ),
                    //     ),
                    //   ],
                    // ),
                    
                    const SizedBox(height: 24),
                    
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}




