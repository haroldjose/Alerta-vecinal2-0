import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';

class ImageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  // Comprime la imagen con flutter_image_compress antes de subir a Firebase Storage.
  Future<File> _compressForUpload(
    File imageFile, {
    int minWidth = 1024,
    int minHeight = 1024,
    int quality = 85,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final targetPath = '${tempDir.path}/compressed_$timestamp.jpg';

      final XFile? result = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        targetPath,
        minWidth: minWidth,
        minHeight: minHeight,
        quality: quality,
        format: CompressFormat.jpeg,
        keepExif: false,
      );

      // Si la compresión falla, retorna el archivo original
      return result != null ? File(result.path) : imageFile;
    } catch (_) {
      // En caso de error inesperado, sube sin compresión adicional
      return imageFile;
    }
  }

  // Seleccionar imagen desde galería o cámara (con compresión inicial de ImagePicker)
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

  // Subir imagen de perfil a Firebase Storage.
  Future<String?> uploadProfileImage(File imageFile, String userId) async {
    try {
      // Segunda pasada de compresión para optimizar tamaño antes de subir
      final compressedFile = await _compressForUpload(
        imageFile,
        minWidth: 800,
        minHeight: 800,
        quality: 85,
      );

      final ref = _storage.ref().child('profile_images/$userId');

      final uploadTask = ref.putFile(compressedFile);
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


  // Aplica compresión adicional con flutter_image_compress antes de la subida.
  Future<String?> uploadReportImage(File imageFile, String reportId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw 'Usuario no autenticado';
      }

      // Segunda pasada de compresión para optimizar tamaño antes de subir
      final compressedFile = await _compressForUpload(
        imageFile,
        minWidth: 1024,
        minHeight: 1024,
        quality: 80,
      );

      final ref = _storage.ref().child('reports/$reportId');

      final uploadTask = ref.putFile(compressedFile);
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
