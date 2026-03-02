import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../core/services/notification_service.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// Provider para el usuario actual
final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(authStateProvider);
  
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      return FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});

// Provider para el servicio de autenticación
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  // Registrar usuario 
  Future<UserModel?> registerUser({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? cargo,
  }) async {
    try {
      final UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? firebaseUser = credential.user;
      if (firebaseUser != null) {
        final userModel = UserModel(
          id: firebaseUser.uid,
          name: name,
          email: email,
          role: role,
          cargo: cargo,
          createdAt: DateTime.now(),
        );

        await _firestore
            .collection('users')
            .doc(firebaseUser.uid)
            .set(userModel.toFirestore());

        await firebaseUser.updateDisplayName(name);
        
        await _notificationService.saveUserToken(firebaseUser.uid);
        
        return userModel;
      } else {
        throw 'No se pudo obtener los datos del usuario creado';
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } on FirebaseException catch (e) {
      throw 'Error de Firebase: ${e.message}';
    } catch (e) {
      throw 'Error inesperado durante el registro: $e';
    }
  }

  // Iniciar sesión
  Future<UserModel?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? firebaseUser = credential.user;
      if (firebaseUser != null) {
        final DocumentSnapshot doc = await _firestore
            .collection('users')
            .doc(firebaseUser.uid)
            .get();
        
        if (doc.exists) {
          
          await _notificationService.saveUserToken(firebaseUser.uid);
          return UserModel.fromFirestore(doc);
        } else {
          throw 'Datos del usuario no encontrados';
        }
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Error inesperado: $e';
    }
    return null;
  }

  // Cerrar sesión
  Future<void> signOut() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        // Eliminar token FCM antes de cerrar sesión
        await _notificationService.removeUserToken(currentUser.uid);
      }
      await _auth.signOut();
    } catch (e) {
      throw 'Error al cerrar sesión: $e';
    }
  }

  // Usuario actual
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Obtener datos del usuario actual desde Firestore
  Future<UserModel?> getCurrentUserData() async {
    final User? firebaseUser = getCurrentUser();
    if (firebaseUser != null) {
      try {
        final DocumentSnapshot doc = await _firestore
            .collection('users')
            .doc(firebaseUser.uid)
            .get();
        
        if (doc.exists) {
          return UserModel.fromFirestore(doc);
        }
      } catch (e) {
        'Error ';
      }
    }
    return null;
  }

  // Manejar excepciones de Firebase Auth
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'La contraseña es muy débil';
      case 'email-already-in-use':
        return 'Este email ya está registrado';
      case 'user-not-found':
        return 'Usuario no encontrado';
      case 'wrong-password':
        return 'Contraseña incorrecta';
      case 'invalid-email':
        return 'Email inválido';
      case 'user-disabled':
        return 'Usuario deshabilitado';
      case 'operation-not-allowed':
        return 'Operación no permitida';
      case 'too-many-requests':
        return 'Demasiados intentos. Intente más tarde';
      case 'network-request-failed':
        return 'Error de conexión. Verifique su internet';
      default:
        return 'Error de autenticación: ${e.message ?? e.code}';
    }
  }
}




