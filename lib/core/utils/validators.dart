import 'package:alerta_vecinal/models/user_model.dart';


class Validators {
  // Validar nombre (solo letras y espacios)
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'El nombre es requerido';
    }
    
    final nameRegex = RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$');
    if (!nameRegex.hasMatch(value)) {
      return 'El nombre solo puede contener letras';
    }
    
    if (value.trim().length < 2) {
      return 'El nombre debe tener al menos 2 caracteres';
    }
    
    return null;
  }

  // Validación cédula de identidad (solo números, máximo 8 dígitos)
  static String? validateCedula(String? value) {
    if (value == null || value.isEmpty) {
      return 'La cédula de identidad es requerida';
    }

    final cedulaRegex = RegExp(r'^[0-9]+$');
    if (!cedulaRegex.hasMatch(value)) {
      return 'La cédula solo puede contener números';
    }

    if (value.length > 8) {
      return 'La cédula no puede tener más de 8 dígitos';
    }

    if (value.length < 5) {
      return 'La cédula debe tener al menos 5 dígitos';
    }

    return null;
  }

  // Validar nombre de usuario, no editable, se verifica que no esté vacío
  static String? validateUsername(String? value) {
    if (value == null || value.isEmpty) {
      return 'El nombre de usuario no puede estar vacío';
    }
    return null;
  }
  
  // Validación celular, solo números y máximo 8 dígitos
  static String? validateCelular(String? value) {
    if (value == null || value.isEmpty) {
      return 'El número de celular es requerido';
    }

    final celularRegex = RegExp(r'^[0-9]+$');
    if (!celularRegex.hasMatch(value)) {
      return 'El celular solo puede contener números';
    }

    if (value.length > 9) {
      return 'El celular no puede tener más de 8 dígitos';
    }

    if (value.length < 8) {
      return 'El celular debe tener 8 dígitos';
    }

    return null;
  }
  // Validar cargo (solo letras y espacios)
  static String? validateCargo(String? value) {
    if (value == null || value.isEmpty) {
      return 'El cargo es requerido';
    }
    
    final cargoRegex = RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$');
    if (!cargoRegex.hasMatch(value)) {
      return 'El cargo solo puede contener letras';
    }
    
    if (value.trim().length < 2) {
      return 'El cargo debe tener al menos 2 caracteres';
    }
    
    return null;
  }
  
  // Validar contraseña (mínimo 8 caracteres)
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña es requerida';
    }
    
    if (value.length < 14) {
      return 'La contraseña debe tener al menos 14 caracteres';
    }
    
    // Verifica que tenga al menos una letra minúscula
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Debe contener al menos una letra minúscula';
    }
    
    // Verifica que tenga al menos una letra mayúscula
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Debe contener al menos una letra mayúscula';
    }
    
    // Verifica que tenga al menos un número
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Debe contener al menos un número';
    }
    // verifica que tenga almenos un caracter especial
    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=\[\]\\;\`~/'']').hasMatch(value)) {
      return 'Debe contener al menos un carácter especial (!@#\$%...)';
    }
    
    return null;
  }
  
  // Valida confirmación de contraseña
  static String? validateConfirmPassword(String? value, String? originalPassword) {
    if (value == null || value.isEmpty) {
      return 'Confirme su contraseña';
    }
    
    if (value != originalPassword) {
      return 'Las contraseñas no coinciden';
    }
    
    return null;
  }
  
  // Valida email
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'El email es requerido';
    }
    
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Ingrese un email válido';
    }
    
    return null;
  }
  
  // Valida selección de rol
  static String? validateRole(UserRole? value) {
    if (value == null) {
      return 'Seleccione un rol';
    }
    return null;
  }

  // genera nombre de usuario, primer nombre + dos primeros digitos de la cédula
 static String generateUsername(String fullName, String cedula) {
    // Extraer el primer nombre
    final firstName = fullName.trim().split(' ').first.toLowerCase();

    // Tomar los primeros 2 dígitos de la cédula 
    final cedulaPrefix = cedula.length >= 2 ? cedula.substring(0, 2) : cedula;

    return '$firstName$cedulaPrefix';
  }

}

