import 'package:cloud_firestore/cloud_firestore.dart'; 

enum UserRole { vecino, admin, security } 

//
enum NotificationCategory {
  inseguridad,
  serviciosBasicos,
  contaminacion,
  convivencia,
}
// Categorias de reportes disponible para suscripción notificaciones
extension NotificationCategoryExtension on NotificationCategory {
  // Nombre legible para mostrar en UI
  String get label {
    switch (this) {
      case NotificationCategory.inseguridad:
        return 'Inseguridad';
      case NotificationCategory.serviciosBasicos:
        return 'Servicios Básicos';
      case NotificationCategory.contaminacion:
        return 'Contaminación';
      case NotificationCategory.convivencia:
        return 'Convivencia';
    }
  }

   // Valor String que se guarda en Firestore / Hive
  String get value {
    switch (this) {
      case NotificationCategory.inseguridad:
        return 'inseguridad';
      case NotificationCategory.serviciosBasicos:
        return 'servicios_basicos';
      case NotificationCategory.contaminacion:
        return 'contaminacion';
      case NotificationCategory.convivencia:
        return 'convivencia';
    }
  }
   // Icono representativo para la UI
  static NotificationCategory fromString(String value) {
    switch (value) {
      case 'servicios_basicos':
        return NotificationCategory.serviciosBasicos;
      case 'contaminacion':
        return NotificationCategory.contaminacion;
      case 'convivencia':
        return NotificationCategory.convivencia;
      case 'inseguridad':
      default:
        return NotificationCategory.inseguridad;
    }
  }
}

//encapsula las preferencias de notificaciones
class NotificationPreferences {
  final bool enabled;
  final bool allCategories;
  final Set<NotificationCategory> selectedCategories;

  const NotificationPreferences({
    this.enabled = true,
    this.allCategories = true,
    this.selectedCategories = const {},
  });

  // Retorna true si el usuario debe recibir notificación para [category].
  bool shouldReceive(String categoryValue) {
    if (!enabled) return false;
    if (allCategories) return true;
    return selectedCategories
        .any((c) => c.value == categoryValue);
  }

  // Serializar a Map para Firestore
  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'allCategories': allCategories,
      'selectedCategories':
          selectedCategories.map((c) => c.value).toList(),
    };
  }

  // Deserializar desde Firestore
  factory NotificationPreferences.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const NotificationPreferences();
    }
    final rawCategories =
        (map['selectedCategories'] as List<dynamic>? ?? [])
            .map((e) => NotificationCategoryExtension.fromString(e as String))
            .toSet();
    return NotificationPreferences(
      enabled: map['enabled'] as bool? ?? true,
      allCategories: map['allCategories'] as bool? ?? true,
      selectedCategories: rawCategories,
    );
  }

  NotificationPreferences copyWith({
    bool? enabled,
    bool? allCategories,
    Set<NotificationCategory>? selectedCategories,
  }) {
    return NotificationPreferences(
      enabled: enabled ?? this.enabled,
      allCategories: allCategories ?? this.allCategories,
      selectedCategories: selectedCategories ?? this.selectedCategories,
    );
  }
}


class UserModel {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? cedula;        // 
  final String? username;      // 
  final String? celular;       //
  final String? cargo;
  final String? profileImage;
  final DateTime createdAt;
  final NotificationPreferences notificationPreferences; //

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.cedula,         //
    this.username,       //
    this.celular,        //
    this.cargo,
    this.profileImage,
    required this.createdAt,
    this.notificationPreferences = const NotificationPreferences(), //
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
       role: parseRole(data['role']),
      cedula: data['cedula'],         // 
      username: data['username'],     // 
      celular: data['celular'],       //
      cargo: data['cargo'],
      profileImage: data['profileImage'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notificationPreferences: NotificationPreferences.fromMap(
        data['notificationPreferences'] as Map<String, dynamic>?,
        ),  //
    );
  }

// método para parsear el rol desde Firestore
  static UserRole parseRole(String? roleStr) {
    switch (roleStr) {
      case 'admin':
        return UserRole.admin;
      case 'security':
        return UserRole.security;
      case 'vecino':
      default:
        return UserRole.vecino;
    }
  }

  // método para convertir el rol a String para Firestore
  static String roleToString(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'admin';
      case UserRole.security:
        return 'security';
      case UserRole.vecino:
        return 'vecino';
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'role': roleToString(role), // 
      'cedula': cedula,           // 
      'username': username,       // 
      'celular': celular,         //
      'cargo': cargo,
      'profileImage': profileImage,
      'createdAt': Timestamp.fromDate(createdAt),
      'notificationPreferences': notificationPreferences.toMap(), //
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
    String? cedula,
    String? username,
    String? celular,
    String? cargo,
    String? profileImage,
    DateTime? createdAt,
    NotificationPreferences? notificationPreferences,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      cedula: cedula ?? this.cedula,       // 
      username: username ?? this.username, // 
      celular: celular ?? this.celular,    //
      cargo: cargo ?? this.cargo,
      profileImage: profileImage ?? this.profileImage,
      createdAt: createdAt ?? this.createdAt,
      notificationPreferences:
          notificationPreferences ?? this.notificationPreferences,
    );
  }
}