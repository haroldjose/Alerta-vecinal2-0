import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/colors.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import 'security_home_screen.dart';

class EditUserScreen extends ConsumerStatefulWidget {
  final DirectoryUser user;
  const EditUserScreen({super.key, required this.user});

  @override
  ConsumerState<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends ConsumerState<EditUserScreen> {
  late final TextEditingController _name;
  late final TextEditingController _cedula;
  late final TextEditingController _celular;
  late final TextEditingController _email;
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  String? _nameError, _cedulaError, _celularError, _emailError;
  String? _passwordError, _confirmError;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user.name);
    _cedula = TextEditingController(text: widget.user.cedula);
    _celular = TextEditingController(text: widget.user.celular);
    _email = TextEditingController(text: widget.user.email);
    _name.addListener(() => setState(() {}));
    _cedula.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_name, _cedula, _celular, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _username {
    final n = _name.text.trim();
    final c = _cedula.text.trim();
    return (n.isNotEmpty && c.isNotEmpty)
        ? Validators.generateUsername(n, c)
        : '';
  }

  Future<void> _save() async {
    final changingPassword =
        _password.text.isNotEmpty || _confirm.text.isNotEmpty;

    setState(() {
      _nameError = Validators.validateName(_name.text);
      _cedulaError = Validators.validateCedula(_cedula.text);
      _celularError = Validators.validateCelular(_celular.text);
      _emailError = Validators.validateEmail(_email.text);
      _passwordError =
          changingPassword ? Validators.validatePassword(_password.text) : null;
      _confirmError = changingPassword
          ? Validators.validateConfirmPassword(_confirm.text, _password.text)
          : null;
    });

    if ([_nameError, _cedulaError, _celularError, _emailError,
            _passwordError, _confirmError]
        .any((e) => e != null)) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(authServiceProvider).updateManagedUser(
            uid: widget.user.id,
            name: _name.text.trim(),
            cedula: _cedula.text.trim(),
            celular: _celular.text.trim(),
            email: _email.text.trim(),
            username: _username,
            password: changingPassword ? _password.text : null,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Editar usuario',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                CustomTextField(
                  hintText: 'Nombre completo',
                  controller: _name,
                  errorText: _nameError,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]')),
                  ],
                ),
                const SizedBox(height: 24),
                CustomTextField(
                  hintText: 'Cédula de identidad',
                  controller: _cedula,
                  errorText: _cedulaError,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(8),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 335,
                  child: Text(
                    'Usuario: ${_username.isEmpty ? '-' : _username}',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 24),
                CustomTextField(
                  hintText: 'Celular',
                  controller: _celular,
                  errorText: _celularError,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(8),
                  ],
                ),
                const SizedBox(height: 24),
                CustomTextField(
                  hintText: 'Email',
                  controller: _email,
                  errorText: _emailError,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 24),
                CustomTextField(
                  hintText: 'Nueva contraseña (opcional)',
                  controller: _password,
                  obscureText: true,
                  showPasswordToggle: true,
                  errorText: _passwordError,
                ),
                const SizedBox(height: 24),
                CustomTextField(
                  hintText: 'Confirmar nueva contraseña',
                  controller: _confirm,
                  obscureText: true,
                  showPasswordToggle: true,
                  errorText: _confirmError,
                ),
                const SizedBox(height: 40),
                CustomButton(
                  text: 'Guardar cambios',
                  onPressed: _save,
                  isLoading: _isLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}