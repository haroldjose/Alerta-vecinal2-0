import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_model.dart';
import '../../core/utils/validators.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../home/home_screen.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants/colors.dart';




class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  // Controladores de texto
  final _nameController = TextEditingController();
  final _cedulaController = TextEditingController();         //
  final _usernameController = TextEditingController();       //
  final _celularController = TextEditingController();        //
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  //estados de error
  String? _nameError;
  String? _cedulaError;     //
  String? _usernameError;   //
  String? _celularError;    //
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _roleError;
  
  bool _isLoading = false;
  UserRole? _selectedRole;

  @override
  void initState() {
    super.initState();
    
    // Agregar listeners para validar mientras se escribe
    _nameController.addListener(_onFieldChanged);
    _cedulaController.addListener(_onCedulaChanged); // 
    _celularController.addListener(_onFieldChanged); //
    _emailController.addListener(_onFieldChanged);
    _passwordController.addListener(_onFieldChanged);
    _confirmPasswordController.addListener(_onFieldChanged);
    
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cedulaController.dispose();    // 
    _usernameController.dispose();  // 
    _celularController.dispose();   // 
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

   // listener regenera el username automáticamente*
  void _onCedulaChanged() {
    _autoGenerateUsername();
    _validateAllFields();
  }

  // Genera el nombre de usuario combinando primer nombre + 2 primeros dígitos de cédula
  void _autoGenerateUsername() {
    final name = _nameController.text.trim();
    final cedula = _cedulaController.text.trim();

    if (name.isNotEmpty && cedula.isNotEmpty) {
      final generated = Validators.generateUsername(name, cedula);
      // Solo actualiza si el valor cambió para evitar rebuilds innecesarios
      if (_usernameController.text != generated) {
        _usernameController.text = generated;
      }
    } else {
      _usernameController.clear();
    }
  }

  // Método se ejecuta cuando cualquier campo cambia
  void _onFieldChanged() {
    _autoGenerateUsername(); // Si el nombre cambia, también hay que regenerar el username
    _validateAllFields();
  }

  // Validación campos mientras se escribe
  void _validateAllFields() {
    setState(() {
      // Validación campos básicos
      _nameError = _nameController.text.isNotEmpty 
          ? Validators.validateName(_nameController.text) 
          : null;
      // validación cédula
      _cedulaError = _cedulaController.text.isNotEmpty
          ? Validators.validateCedula(_cedulaController.text)
          : null;

      // validación username (autogenerado, solo muestra error si está vacío)
      _usernameError = _usernameController.text.isNotEmpty
          ? null
          : null; 

      // validación celular
      _celularError = _celularController.text.isNotEmpty
          ? Validators.validateCelular(_celularController.text)
          : null;    
      
      _emailError = _emailController.text.isNotEmpty 
          ? Validators.validateEmail(_emailController.text) 
          : null;
      
      _passwordError = _passwordController.text.isNotEmpty 
          ? Validators.validatePassword(_passwordController.text) 
          : null;
      
      _confirmPasswordError = _confirmPasswordController.text.isNotEmpty 
          ? Validators.validateConfirmPassword(_confirmPasswordController.text, _passwordController.text) 
          : null;
      
      // Validación rol 
      _roleError = _selectedRole == null ? null : null;
      
    });
  }

  // Validación antes del envío 
  void _validateForSubmission() {
    setState(() {
      _nameError = Validators.validateName(_nameController.text);
      _cedulaError = Validators.validateCedula(_cedulaController.text);         // 
      _usernameError = Validators.validateUsername(_usernameController.text);   // 
      _celularError = Validators.validateCelular(_celularController.text);      //
      _emailError = Validators.validateEmail(_emailController.text);
      _passwordError = Validators.validatePassword(_passwordController.text);
      _confirmPasswordError = Validators.validateConfirmPassword(
        _confirmPasswordController.text,
        _passwordController.text,
      );
      _roleError = _selectedRole == null ? 'Seleccione un rol' : null;
      
    });
  }

  // Verificando si el formulario es válido *
  bool get _isFormValid {
    final hasAllRequiredFields = _nameController.text.isNotEmpty &&
        _cedulaController.text.isNotEmpty &&     // 
        _usernameController.text.isNotEmpty &&   // 
        _celularController.text.isNotEmpty &&    //
        _emailController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        _confirmPasswordController.text.isNotEmpty &&
        _selectedRole != null;

    final hasNoErrors = _nameError == null &&
        _cedulaError == null &&           // 
        _usernameError == null &&         // 
        _celularError == null &&  
        _emailError == null &&
        _passwordError == null &&
        _confirmPasswordError == null &&
        _roleError == null;

    final isValid = hasAllRequiredFields && hasNoErrors;
    return isValid;
  }


  //*
  Future<void> _register() async {
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
      
      final user = await authService.registerUser(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        role: _selectedRole!,
        cedula: _cedulaController.text.trim(),       // 
        username: _usernameController.text.trim(),   // 
        celular: _celularController.text.trim(),     //
      );

      if (user != null && mounted) {
        _showSuccessMessage('¡Registro exitoso! Bienvenido ${user.name}');
        
        await Future.delayed(const Duration(milliseconds: 1500));
        
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              
              const Text(
                'Registrarse',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Crea tu cuenta para comenzar',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Formulario
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    //
                    CustomTextField(
                      hintText: 'Nombre completo', 
                      controller: _nameController,
                      errorText: _nameError,
                      inputFormatters:[ //
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]')),

                      ], 
                      ),

                      const SizedBox(height: 24,),
                      //
                      CustomTextField(
                      hintText: 'Cédula de identidad',
                      controller: _cedulaController,
                      errorText: _cedulaError,
                      keyboardType: TextInputType.number,
                      // Solo números, máximo 8 dígitos
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(8),
                      ],
                    ),

                    const SizedBox(height: 24),
                  
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              'Nombre de usuario (autogenerado)',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        Container(
                          width: double.infinity,
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppColors.border,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey.shade100,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _usernameController.text.isEmpty
                              ? 'Segenera automaticamente'
                              : _usernameController.text,
                                style: TextStyle(
                                  color: _usernameController.text.isEmpty
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Campo Celular 
                    CustomTextField(
                      hintText: 'Celular',
                      controller: _celularController,
                      errorText: _celularError,
                      keyboardType: TextInputType.number,
                      // Solo números, máximo 8 dígitos
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(8),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Campo Email 
                    CustomTextField(
                      hintText: 'Email',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      errorText: _emailError,
                    ),

                    const SizedBox(height: 24),

                    // Campo Contraseña 
                    CustomTextField(
                      hintText: 'Contraseña',
                      controller: _passwordController,
                      obscureText: true,
                      errorText: _passwordError,
                    ),

                    // indicador de requisitos de contraseña
                    if (_passwordController.text.isNotEmpty && _passwordError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Mínimo 14 caracteres, mayúscula, minúscula, número y carácter especial',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Campo Confirmar contraseña
                    CustomTextField(
                      hintText: 'Confirmar contraseña',
                      controller: _confirmPasswordController,
                      obscureText: true,
                      errorText: _confirmPasswordError,
                    ),

                    const SizedBox(height: 24),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_roleError != null && _roleError!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              _roleError!,
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        Container(
                          width: double.infinity,
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _roleError != null && _roleError!.isNotEmpty
                                  ? AppColors.error
                                  : AppColors.border,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.white,
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<UserRole>(
                              value: _selectedRole,
                              isExpanded: true,
                              hint: const Text(
                                'Asignación de rol',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                              icon: const Icon(Icons.arrow_drop_down,
                                  color: AppColors.primary),
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                              ),
                              //tres roles disponibles
                              items: const [
                                DropdownMenuItem(
                                  value: UserRole.vecino,
                                  child: Text('Vecino'),
                                ),
                                DropdownMenuItem(
                                  value: UserRole.admin,
                                  child: Text('Administrador'),
                                ),
                                //opción de Seguridad
                                DropdownMenuItem(
                                  value: UserRole.security,
                                  child: Text('Seguridad'),
                                ),
                              ],
                              onChanged: (UserRole? newValue) {
                                setState(() {
                                  _selectedRole = newValue;
                                });
                                _validateAllFields();
                              },
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    // Boton Registrarse
                    CustomButton(
                      text: 'Registrarse',
                      onPressed: _isFormValid ? _register : null,
                      isLoading: _isLoading,
                    ),

                    const SizedBox(height: 24),

                    // enlace Iniciar sesión 
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '¿Ya tienes cuenta? ',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Text(
                            'Iniciar sesión',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
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
 