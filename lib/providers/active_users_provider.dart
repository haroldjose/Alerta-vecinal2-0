import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Modelo para usuarios activos
class ActiveUser {
  final String id;
  final String name;
  final String email;
  final DateTime lastActive;
  final bool isOnline;

  ActiveUser({
    required this.id,
    required this.name,
    required this.email,
    required this.lastActive,
    required this.isOnline,
  });

  factory ActiveUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final lastActive = (data['lastActive'] as Timestamp?)?.toDate() ?? DateTime.now();
    final now = DateTime.now();
    final difference = now.difference(lastActive);
    
    return ActiveUser(
      id: doc.id,
      name: data['name'] ?? 'Usuario',
      email: data['email'] ?? '',
      lastActive: lastActive,
      isOnline: difference.inMinutes < 2, 
    );
  }

  String get statusText {
    if (isOnline) return 'En línea';
    
    final now = DateTime.now();
    final difference = now.difference(lastActive);
    
    if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Hace ${difference.inHours} hora${difference.inHours > 1 ? 's' : ''}';
    } else {
      return 'Hace ${difference.inDays} día${difference.inDays > 1 ? 's' : ''}';
    }
  }
}

// Provider para obtener usuarios activos
final activeUsersProvider = StreamProvider.autoDispose<List<ActiveUser>>((ref) {
  
  final link = ref.keepAlive();
  
  Timer? timer;
  timer = Timer(const Duration(seconds: 30), () {
    link.close();
  });
  
  ref.onDispose(() {
    timer?.cancel();
  });

  // Stream con manejo robusto de errores
  return FirebaseFirestore.instance
      .collection('users')
      .orderBy('lastActive', descending: true)
      .limit(50)
      .snapshots()
      .handleError((error) {
        
        if (error.toString().contains('permission-denied')) {
          'Sin permisos para acceder a usuarios';
        } else if (error.toString().contains('UNAVAILABLE')) {
          'Servidor no disponible, reintentando...';
        } else {
          'Error en activeUsersProvider: $error';
        }
        return null;
      })
      .where((snapshot) => snapshot != null)
      .map((snapshot) {
        try {
          if (snapshot == null) return <ActiveUser>[];
          
          return snapshot.docs
              .map((doc) {
                try {
                  return ActiveUser.fromFirestore(doc);
                } catch (e) {
                  
                  return null;
                }
              })
              .whereType<ActiveUser>() 
              .toList();
        } catch (e) {
          
          return <ActiveUser>[];
        }
      });
});

// Provider para actualizar la última actividad del usuario
final userActivityServiceProvider = Provider((ref) => UserActivityService());

class UserActivityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  
  Future<void> updateUserActivity(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'lastActive': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      'Error updating user activity';
    }
  }

  // Inicializar listener para actualizar actividad periódicamente
  void startActivityTracking(String userId) {
    
    updateUserActivity(userId).catchError((e) {
      
    });
    
    
    Future.delayed(const Duration(minutes: 1), () {
      updateUserActivity(userId).catchError((e) {
        
      });
      startActivityTracking(userId); 
    });
  }
}