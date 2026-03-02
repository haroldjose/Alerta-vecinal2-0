import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ImageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  // Seleccionar imagen desde galería o cámara
  Future<File?> pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 80,
      );

      if (image != null) {
        return File(image.path);
      }
    } catch (e) {
      throw 'Error al seleccionar imagen: $e';
    }
    return null;
  }

  // Subir imagen de perfil a Firebase Storage
  Future<String?> uploadProfileImage(File imageFile, String userId) async {
    try {
      //
      final ref = _storage.ref().child('profile_images/$userId');
      
      final uploadTask = ref.putFile(imageFile);
      final snapshot = await uploadTask;
      
      if (snapshot.state == TaskState.success) {
        final downloadUrl = await ref.getDownloadURL();
        return downloadUrl;
      }
    } catch (e) {
      throw 'Error al subir imagen: $e';
    }
    return null;
  }

  // Subir imagen de reporte a Firebase Storage
  Future<String?> uploadReportImage(File imageFile, String reportId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw 'Usuario no autenticado';
      }
      
      //
      final ref = _storage.ref().child('reports/$reportId');
      
      final uploadTask = ref.putFile(imageFile);
      final snapshot = await uploadTask;
      
      if (snapshot.state == TaskState.success) {
        final downloadUrl = await ref.getDownloadURL();
        return downloadUrl;
      }
    } catch (e) {
      throw 'Error al subir imagen del reporte: $e';
    }
    return null;
  }

  Future<void> deleteProfileImage(String userId) async {
    try {
      //
      final ref = _storage.ref().child('profile_images/$userId');
      await ref.delete();
    } catch (e) {
      throw 'Error al eliminar imagen: $e';
    }
  }

  Future<File?> showImageSourceDialogSafe(BuildContext context) async {
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
      return await pickImage(source: source);
    }
    return null;
  }
}

