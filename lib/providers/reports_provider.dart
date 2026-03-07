import 'dart:io';
import 'package:alerta_vecinal/models/user_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/report_model.dart';
import '../models/local_models.dart';
import '../core/services/image_service.dart';
import '../core/services/location_service.dart';
import '../core/services/notification_service.dart';
import '../core/services/local_storage_service.dart';
import '../core/services/connectivity_service.dart';
import '../core/services/sync_service.dart';
import 'auth_provider.dart';

// Provider para el servicio de ubicación
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

// Provider para el servicio de conectividad
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

// Provider para el servicio de sincronización
final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService();
});

// Provider para el estado de conectividad
final connectivityStatusProvider = StreamProvider<bool>((ref) {
  final connectivity = ref.watch(connectivityServiceProvider);
  return connectivity.connectionStatus;
});

// Provider para el estado de sincronización
final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final sync = ref.watch(syncServiceProvider);
  return sync.syncStatus;
});

// Provider para el servicio de reportes local + Firebase
final reportServiceProvider = Provider<ReportService>((ref) {
  return ReportService();
});

// Provider para obtener todos los reportes local + Firebase
final reportsStreamProvider = StreamProvider<List<ReportModel>>((ref) {
  final connectivity = ref.watch(connectivityServiceProvider);
  final localStorage = LocalStorageService();

  if (connectivity.hasConnection) {
    return FirebaseFirestore.instance
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .handleError((error) {
          final localReports = localStorage.getAllReports();
          final reports = localReports.map((local) => local.toReportModel()).toList();
          reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return Stream.value(reports);
        })
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ReportModel.fromFirestore(doc))
              .toList();
        });
  } else {
    return Stream.periodic(const Duration(milliseconds: 100), (_) {
      final localReports = localStorage.getAllReports();
      final reports = localReports
          .map((local) => local.toReportModel())
          .toList();
      reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return reports;
    });
  }
});

// Provider para reportes filtrados por tipo
final reportsByTypeProvider =
    StreamProvider.family<List<ReportModel>, ProblemType>((ref, problemType) {
      final connectivity = ref.watch(connectivityServiceProvider);
      final localStorage = LocalStorageService();

      if (connectivity.hasConnection) {
        return FirebaseFirestore.instance
            .collection('reports')
            .where('problemType', isEqualTo: problemType.value)
            .orderBy('createdAt', descending: true)
            .snapshots()
            .handleError((error) {
              final localReports = localStorage.getReportsByType(problemType);
              final reports = localReports.map((local) => local.toReportModel()).toList();
              reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
              return Stream.value(reports);
            })
            .map((snapshot) {
              return snapshot.docs
                  .map((doc) => ReportModel.fromFirestore(doc))
                  .toList();
            });
      } else {
        return Stream.periodic(const Duration(milliseconds: 500), (_) {
          final localReports = localStorage.getReportsByType(problemType);
          final reports = localReports
              .map((local) => local.toReportModel())
              .toList();
          reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return reports;
        }).distinct();
      }
    });

// Provider para los reportes del usuario actual
final myReportsStreamProvider =
    StreamProvider.family<List<ReportModel>, String>((ref, userId) {
      final connectivity = ref.watch(connectivityServiceProvider);
      final localStorage = LocalStorageService();

      if (connectivity.hasConnection) {
        return FirebaseFirestore.instance
            .collection('reports')
            .where('userId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .snapshots()
            .handleError((error) {
              final localReports = localStorage.getReportsByUser(userId);
              final reports = localReports.map((local) => local.toReportModel()).toList();
              reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
              return Stream.value(reports);
            })
            .map((snapshot) {
              return snapshot.docs
                  .map((doc) => ReportModel.fromFirestore(doc))
                  .toList();
            });
      } else {
        return Stream.periodic(const Duration(milliseconds: 500), (_) {
          final localReports = localStorage.getReportsByUser(userId);
          final reports = localReports
              .map((local) => local.toReportModel())
              .toList();
          reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return reports;
        }).distinct();
      }
    });

// Provider para contar los reportes del usuario
final myReportsCountProvider = StreamProvider<int>((ref) {
  final currentUser = ref.watch(currentUserProvider);
  final connectivity = ref.watch(connectivityServiceProvider);
  final localStorage = LocalStorageService();
  
  return currentUser.when(
    data: (user) {
      if (user == null) return Stream.value(0);
      
      if (connectivity.hasConnection) {
        return FirebaseFirestore.instance
            .collection('reports')
            .where('userId', isEqualTo: user.id)
            .snapshots()
            .handleError((error) {
              final count = localStorage.getReportsByUser(user.id).length;
              return Stream.value(count);
            })
            .map((snapshot) => snapshot.docs.length);
      } else {
        return Stream.periodic(const Duration(milliseconds: 500), (_) {
          return localStorage.getReportsByUser(user.id).length;
        }).distinct();
      }
    },
    loading: () => Stream.value(0),
    error: (_, __) => Stream.value(0),
  );
});

class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  final LocalStorageService _localStorage = LocalStorageService();
  final ConnectivityService _connectivity = ConnectivityService();

  Future<void> createReport({
    required String userId,
    required String userName,
    required ProblemType problemType,
    required String title,
    required String description,
    File? imageFile,
    LocationData? location,
  }) async {
    final reportId = _firestore.collection('reports').doc().id;
    final now = DateTime.now();
    String? localImagePath;

    if (imageFile != null) {
      localImagePath = await _localStorage.saveLocalImage(imageFile, reportId);
    }

    // Crear reporte local
    final localReport = LocalReportModel(
      id: reportId,
      userId: userId,
      userName: userName,
      problemType: problemType.value,
      status: ReportStatus.pendiente.value,
      title: title,
      description: description,
      localImagePath: localImagePath,
      latitude: location?.latitude,
      longitude: location?.longitude,
      address: location?.address,
      createdAt: now,
      updatedAt: now,
      isSynced: false,
    );

    // Guardar en almacenamiento local  
    await _localStorage.saveReport(localReport);

    // Intentar sincronizar en segundo plano 
    if (_connectivity.hasConnection) {
      _syncCreateToFirebase(
        reportId: reportId,
        userId: userId,
        userName: userName,
        problemType: problemType,
        title: title,
        description: description,
        imageFile: imageFile,
        location: location,
        localImagePath: localImagePath,
        localReport: localReport,
      ).catchError((e) {
        _savePendingCreateOperation(localReport, localImagePath);
      });
    } else {
      await _savePendingCreateOperation(localReport, localImagePath);
    }
    
  }

  Future<void> _syncCreateToFirebase({
    required String reportId,
    required String userId,
    required String userName,
    required ProblemType problemType,
    required String title,
    required String description,
    File? imageFile,
    LocationData? location,
    String? localImagePath,
    required LocalReportModel localReport,
  }) async {
    String? imageUrl;

    if (imageFile != null) {
      final imageService = ImageService();
      imageUrl = await imageService.uploadReportImage(imageFile, reportId);
      await _localStorage.deleteLocalImage(reportId);
    }

    final report = ReportModel(
      id: reportId,
      userId: userId,
      userName: userName,
      problemType: problemType,
      status: ReportStatus.pendiente,
      title: title,
      description: description,
      imageUrl: imageUrl,
      location: location,
      createdAt: localReport.createdAt,
      updatedAt: DateTime.now(),
    );

    await _firestore.collection('reports').doc(reportId).set(report.toFirestore());

    await _localStorage.saveReport(
      localReport.copyWith(isSynced: true, imageUrl: imageUrl)
    );

    _notificationService.sendReportNotificationToAll(
      reportId: reportId,
      reportTitle: title,
      reportType: problemType.value,
      creatorId: userId,
    ).catchError((error) {
      'Error al enviar notificación: $error';
    });

  }

  Future<void> _savePendingCreateOperation(
    LocalReportModel report,
    String? localImagePath,
  ) async {
    final operation = PendingOperation(
      id: '${report.id}_create',
      type: 'create',
      reportId: report.id,
      data: {
        'userId': report.userId,
        'userName': report.userName,
        'problemType': report.problemType,
        'status': report.status,
        'title': report.title,
        'description': report.description,
        'localImagePath': localImagePath,
        'location': report.latitude != null && report.longitude != null
            ? {
                'latitude': report.latitude,
                'longitude': report.longitude,
                'address': report.address,
              }
            : null,
        'createdAt': report.createdAt.toIso8601String(),
      },
      timestamp: DateTime.now(),
    );

    await _localStorage.addPendingOperation(operation);
  }

  Future<void> updateReport({
    required String reportId,
    required String userId,
    required ProblemType problemType,
    required String title,
    required String description,
    File? imageFile,
    String? existingImageUrl,
    LocationData? location,
  }) async {
    String? localImagePath;

    if (imageFile != null) {
      localImagePath = await _localStorage.saveLocalImage(imageFile, reportId);
    }

    // Actualizar reporte local
    final existingReport = _localStorage.getReport(reportId);
    if (existingReport != null) {
      final updatedReport = existingReport.copyWith(
        problemType: problemType.value,
        title: title,
        description: description,
        localImagePath: localImagePath ?? existingReport.localImagePath,
        latitude: location?.latitude,
        longitude: location?.longitude,
        address: location?.address,
        updatedAt: DateTime.now(),
        isSynced: false,
      );

      await _localStorage.saveReport(updatedReport);
    }

    // Intentar sincronizar en segundo plano
    if (_connectivity.hasConnection) {
      _syncUpdateToFirebase(
        reportId: reportId,
        problemType: problemType,
        title: title,
        description: description,
        imageFile: imageFile,
        existingImageUrl: existingImageUrl,
        location: location,
        localImagePath: localImagePath,
      ).catchError((e) {
        _savePendingUpdateOperation(
          reportId, problemType, title, description,
          localImagePath, existingImageUrl, location
        );
      });
    } else {
      await _savePendingUpdateOperation(
        reportId, problemType, title, description,
        localImagePath, existingImageUrl, location
      );
    }
  }

  Future<void> _syncUpdateToFirebase({
    required String reportId,
    required ProblemType problemType,
    required String title,
    required String description,
    File? imageFile,
    String? existingImageUrl,
    LocationData? location,
    String? localImagePath,
  }) async {
    String? imageUrl = existingImageUrl;
    
    if (imageFile != null) {
      final imageService = ImageService();
      imageUrl = await imageService.uploadReportImage(imageFile, reportId);
      await _localStorage.deleteLocalImage(reportId);
    }

    await _firestore.collection('reports').doc(reportId).update({
      'problemType': problemType.value,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'location': location?.toMap(),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    final report = _localStorage.getReport(reportId);
    if (report != null) {
      await _localStorage.saveReport(
        report.copyWith(isSynced: true, imageUrl: imageUrl)
      );
    }
  }

  Future<void> _savePendingUpdateOperation(
    String reportId,
    ProblemType problemType,
    String title,
    String description,
    String? localImagePath,
    String? existingImageUrl,
    LocationData? location,
  ) async {
    final operation = PendingOperation(
      id: '${reportId}_update',
      type: 'update',
      reportId: reportId,
      data: {
        'problemType': problemType.value,
        'title': title,
        'description': description,
        'localImagePath': localImagePath,
        'existingImageUrl': existingImageUrl,
        'location': location?.toMap(),
      },
      timestamp: DateTime.now(),
    );

    await _localStorage.addPendingOperation(operation);
  }

  Future<void> updateReportStatus(String reportId, ReportStatus status) async {
    
    final report = _localStorage.getReport(reportId);
    if (report != null) {
      await _localStorage.saveReport(
        report.copyWith(status: status.value, isSynced: false, updatedAt: DateTime.now())
      );
    }

    // Intentar sincronizar en segundo plano
    if (_connectivity.hasConnection) {
      _syncStatusToFirebase(reportId, status).catchError((e) {
        _savePendingStatusOperation(reportId, status);
      });
    } else {
      await _savePendingStatusOperation(reportId, status);
    }
  }

  Future<void> _syncStatusToFirebase(String reportId, ReportStatus status) async {
    await _firestore.collection('reports').doc(reportId).update({
      'status': status.value,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    final report = _localStorage.getReport(reportId);
    if (report != null) {
      await _localStorage.saveReport(
        report.copyWith(status: status.value, isSynced: true)
      );
    }
    
  }

  Future<void> _savePendingStatusOperation(String reportId, ReportStatus status) async {
    final operation = PendingOperation(
      id: '${reportId}_status',
      type: 'updateStatus',
      reportId: reportId,
      data: {'status': status.value},
      timestamp: DateTime.now(),
    );
    await _localStorage.addPendingOperation(operation);
  }

  Future<void> deleteReport(String reportId) async {
    
    await _localStorage.deleteReport(reportId);
    await _localStorage.deleteLocalImage(reportId);

    // Intentar sincronizar en segundo plano
    if (_connectivity.hasConnection) {
      _syncDeleteToFirebase(reportId).catchError((e) {
        _savePendingDeleteOperation(reportId);
      });
    } else {
      await _savePendingDeleteOperation(reportId);
    }
  }

  Future<void> _syncDeleteToFirebase(String reportId) async {
    await _firestore.collection('reports').doc(reportId).delete();
  }

  Future<void> _savePendingDeleteOperation(String reportId) async {
    final operation = PendingOperation(
      id: '${reportId}_delete',
      type: 'delete',
      reportId: reportId,
      data: {},
      timestamp: DateTime.now(),
    );
    await _localStorage.addPendingOperation(operation);
  }

  Stream<List<ReportModel>> getReportsByUser(String userId) {
    if (_connectivity.hasConnection) {
      return _firestore
          .collection('reports')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => ReportModel.fromFirestore(doc))
                .toList();
          });
    } else {
      final reports = _localStorage.getReportsByUser(userId)
          .map((local) => local.toReportModel())
          .toList();
      
      reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return Stream.value(reports);
    }
  }
}

// StateNotifier para crear reportes
class CreateReportNotifier extends StateNotifier<AsyncValue<void>> {
  CreateReportNotifier(this.ref) : super(const AsyncValue.data(null));

  final Ref ref;

  Future<void> createReport({
    required ProblemType problemType,
    required String title,
    required String description,
    File? imageFile,
    LocationData? location,
  }) async {
    state = const AsyncValue.loading();

    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw 'Usuario no autenticado';
      }

      final reportService = ref.read(reportServiceProvider);
      
      await reportService.createReport(
        userId: currentUser.id,
        userName: currentUser.name,
        problemType: problemType,
        title: title,
        description: description,
        imageFile: imageFile,
        location: location,
      );

      // Invalidar providers
      ref.invalidate(reportsStreamProvider);
      ref.invalidate(myReportsStreamProvider(currentUser.id));
      ref.invalidate(myReportsCountProvider);
      for (final type in ProblemType.values) {
        ref.invalidate(reportsByTypeProvider(type));
      }

      await Future.delayed(const Duration(milliseconds: 100));
      state = const AsyncValue.data(null);
      
    } catch (e, stack) {
      state = AsyncValue.error(e.toString(), stack);
    }
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}

// StateNotifier para editar reportes
class EditReportNotifier extends StateNotifier<AsyncValue<void>> {
  EditReportNotifier(this.ref) : super(const AsyncValue.data(null));

  final Ref ref;

  Future<void> updateReport({
    required String reportId,
    required String userId,
    required ProblemType problemType,
    required String title,
    required String description,
    File? imageFile,
    String? existingImageUrl,
    LocationData? location,
  }) async {
    state = const AsyncValue.loading();

    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw 'Usuario no autenticado';
      }
      
      final isAdmin = currentUser.role == UserRole.admin;
      if (!isAdmin && currentUser.id != userId) {
        throw 'No tienes permiso para editar este reporte';
      }

      final reportService = ref.read(reportServiceProvider);
      
      await reportService.updateReport(
        reportId: reportId,
        userId: userId,
        problemType: problemType,
        title: title,
        description: description,
        imageFile: imageFile,
        existingImageUrl: existingImageUrl,
        location: location,
      );

      // Invalidar providers
      ref.invalidate(reportsStreamProvider);
      ref.invalidate(myReportsStreamProvider(userId));
      for (final type in ProblemType.values) {
        ref.invalidate(reportsByTypeProvider(type));
      }

      await Future.delayed(const Duration(milliseconds: 100));
      state = const AsyncValue.data(null);
      
    } catch (e, stack) {
      state = AsyncValue.error(e.toString(), stack);
    }
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}

// Provider para crear reportes
final createReportProvider =
    StateNotifierProvider<CreateReportNotifier, AsyncValue<void>>((ref) {
      return CreateReportNotifier(ref);
    });

// Provider para editar reportes
final editReportProvider =
    StateNotifierProvider<EditReportNotifier, AsyncValue<void>>((ref) {
      return EditReportNotifier(ref);
    });

