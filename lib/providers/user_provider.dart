
import 'dart:io';

import 'package:alerta_vecinal/core/services/image_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final imageServiceProvider = Provider<ImageService>((ref){
  return ImageService();
});
 
final userServiceProvider = Provider<UserService>((ref){
  return UserService();
});

class UserService{
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

// actualizar imagen 
  Future<void> updateProfileImage(String userId, String imageUrl) async{
    
    try{
      await _firestore.collection('users').doc(userId).update({'profileImage': imageUrl});
    }catch(e){
      throw 'Error al actualizar imagen de perfil: $e';
    }
  }

  // actualizar usuario
  Future<void> updateUser(String userId, Map<String,dynamic> data) async{
    
    try{
      await _firestore.collection('users').doc(userId).update(data);
    }catch(e){
      throw 'Error al actualizar usuario: $e';
    }
  }
}

//manejar subida imagen perfil
class ProfileImageNotifier extends StateNotifier<AsyncValue<String?>>{
  final Ref ref;
  ProfileImageNotifier(this.ref) : super(AsyncValue.data(null));

 //subir la imagen
 Future<void> uploadProfileImage(File imageFile, String userId) async{
  
  state = AsyncValue.loading();
  
  try{
    final imageService = ref.read(imageServiceProvider);
    final userService = ref.read(userServiceProvider);

    final imageUrl = await imageService.uploadProfileImage(imageFile, userId);

    if(imageUrl != null){
      
      await userService.updateProfileImage(userId, imageUrl);
      
      state = AsyncValue.data(imageUrl);
    }else{
      state = AsyncValue.error('No se pudo subir la imagen', StackTrace.empty);
    }
  }catch(e, stack){
    state = AsyncValue.error(e.toString(), stack);
  }
 }

 void reset(){
  state = AsyncValue.data(null);
 }

 // Método alternativo para actualizar directamente (método de respaldo)
 Future<void> updateProfileImageUrl(String downloadUrl, String userId) async {
       
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId) 
          .update({'profileImage': downloadUrl});
      
      state = AsyncValue.data(downloadUrl);
    } catch (e) {
      throw 'Error al actualizar la base de datos: $e';
    }
  }
}

final profileImageProvider = StateNotifierProvider<ProfileImageNotifier, AsyncValue<String?>>((ref){
 return ProfileImageNotifier(ref);
});


