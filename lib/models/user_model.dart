import 'package:cloud_firestore/cloud_firestore.dart'; 

enum UserRole { vecino, admin, security } 

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
    );
  }
}