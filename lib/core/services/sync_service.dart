import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/local_models.dart';
import '../../models/report_model.dart';
import 'local_storage_service.dart';
import 'connectivity_service.dart';
import 'image_service.dart';
import 'notification_service.dart';

// Servicio para sincronizar datos entre local y Firebase
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final LocalStorageService _localStorage = LocalStorageService();
  final ConnectivityService _connectivity = ConnectivityService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImageService _imageService = ImageService();
  final NotificationService _notificationService = NotificationService();

  bool _isSyncing = false;
  StreamSubscription<bool>? _connectivitySubscription;
  StreamSubscription<QuerySnapshot>? _reportsSubscription;
  Timer? _periodicSyncTimer;

  final StreamController<SyncStatus> _syncStatusController = 
      StreamController<SyncStatus>.broadcast();

  // Stream del estado de sincronización
  Stream<SyncStatus> get syncStatus => _syncStatusController.stream;

  // Inicializar el servicio de sincronización
  Future<void> initialize() async {
    
    _connectivitySubscription = _connectivity.connectionStatus.listen((hasConnection) async {
      if (hasConnection) {
        
        // Sincronizar inmediatamente 
        syncAll().catchError((error) {
          'Error en sincronización automática: $error';
        });
        
        if (_reportsSubscription == null) {
          _subscribeToFirebaseChanges();
        }

        _startPeriodicSync();
      } else {
        
        _stopPeriodicSync();
      }
    });

    // Escuchar cambios en Firebase para actualizar cache local 
    if (_connectivity.hasConnection) {
      _subscribeToFirebaseChanges();
    }

    // Sincronización inicial si hay conexión
    if (_connectivity.hasConnection) {
      await syncAll();
      _startPeriodicSync();
    } else {
      'Iniciando en modo offline';
    }
  }

  /// Suscribirse a cambios en Firebase
  void _subscribeToFirebaseChanges() {
    
    if (!_connectivity.hasConnection) {
      
      return;
    }

    _reportsSubscription = _firestore
        .collection('reports')
        .snapshots()
        .listen((snapshot) async {
      if (_connectivity.hasConnection && !_isSyncing) {
        await _updateLocalCache(snapshot.docs);
      }
    }, onError: (error) {
      
      if (!error.toString().contains('UNAVAILABLE')) {
        
      }
    });
  }

  // Actualizar caché local con datos de Firebase
  Future<void> _updateLocalCache(List<QueryDocumentSnapshot> docs) async {
    try {
      for (var doc in docs) {
        final report = ReportModel.fromFirestore(doc);
        final localReport = LocalReportModel.fromReportModel(report, isSynced: true);
        await _localStorage.saveReport(localReport);
      }
      
    } catch (e) {
      'Error al actualizar cache local: $e';
    }
  }

  // Sincronizar todo 
  Future<void> syncAll() async {
    if (_isSyncing) {
      return;
    }

    if (!_connectivity.hasConnection) {
      _syncStatusController.add(SyncStatus.offline);
      return;
    }

    _isSyncing = true;
    _syncStatusController.add(SyncStatus.syncing);

    try {
      
      // 1. Sincronizar operaciones pendientes
      await _syncPendingOperations();

      // 2. Actualizar cache local desde Firebase
      await _downloadLatestReports();

      _syncStatusController.add(SyncStatus.synced);
      
    } catch (e) {
      _syncStatusController.add(SyncStatus.error);
      
    } finally {
      _isSyncing = false;
    }
  }

  // Sincronizar operaciones pendientes
  Future<void> _syncPendingOperations() async {
    final operations = _localStorage.getPendingOperations();
    
    if (operations.isEmpty) {
      
      return;
    }

    for (var operation in operations) {
      try {
        await _executePendingOperation(operation);
        await _localStorage.removePendingOperation(operation.id);
        
      } catch (e) {
        'Error al sincronizar operación ${operation.id}: $e';
        
        // Incrementar contador de reintentos
        final newRetryCount = operation.retryCount + 1;
        if (newRetryCount >= 5) {
          await _localStorage.removePendingOperation(operation.id);
        } else {
          await _localStorage.updateOperationRetryCount(operation.id, newRetryCount);
        }
      }
    }
  }

  /// Ejecutar una operación pendiente
  Future<void> _executePendingOperation(PendingOperation operation) async {
    switch (operation.type) {
      case 'create':
        await _syncCreateReport(operation);
        break;
      case 'update':
        await _syncUpdateReport(operation);
        break;
      case 'delete':
        await _syncDeleteReport(operation);
        break;
      case 'updateStatus':
        await _syncUpdateStatus(operation);
        break;
      default:
        'Tipo de operación desconocido: ${operation.type}';
    }
  }

  // Sincronizar creación de reporte
  Future<void> _syncCreateReport(PendingOperation operation) async {
    final data = operation.data;
    String? imageUrl;

    // Subir imagen si existe
    if (data['localImagePath'] != null) {
      final imageFile = File(data['localImagePath'] as String);
      if (await imageFile.exists()) {
        imageUrl = await _imageService.uploadReportImage(imageFile, operation.reportId);
        // Eliminar imagen local después de subirla
        await _localStorage.deleteLocalImage(operation.reportId);
      }
    }

    // Crear reporte en Firebase
    final reportData = {
      'userId': data['userId'],
      'userName': data['userName'],
      'problemType': data['problemType'],
      'status': data['status'],
      'title': data['title'],
      'description': data['description'],
      'imageUrl': imageUrl,
      'location': data['location'],
      'createdAt': Timestamp.fromDate(DateTime.parse(data['createdAt'] as String)),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };

    await _firestore.collection('reports').doc(operation.reportId).set(reportData);

    // Enviar notificación
    await _notificationService.sendReportNotificationToAll(
      reportId: operation.reportId,
      reportTitle: data['title'] as String,
      reportType: data['problemType'] as String,
      creatorId: data['userId'] as String,
    );

    // Actualizar reporte local como sincronizado
    final localReport = _localStorage.getReport(operation.reportId);
    if (localReport != null) {
      await _localStorage.saveReport(
        localReport.copyWith(isSynced: true, imageUrl: imageUrl)
      );
    }
  }

  // Sincronizar actualización de reporte
  Future<void> _syncUpdateReport(PendingOperation operation) async {
    final data = operation.data;
    String? imageUrl = data['existingImageUrl'] as String?;

    // Subir nueva imagen si existe
    if (data['localImagePath'] != null) {
      final imageFile = File(data['localImagePath'] as String);
      if (await imageFile.exists()) {
        imageUrl = await _imageService.uploadReportImage(imageFile, operation.reportId);
        await _localStorage.deleteLocalImage(operation.reportId);
      }
    }

    // Actualizar en Firebase
    await _firestore.collection('reports').doc(operation.reportId).update({
      'problemType': data['problemType'],
      'title': data['title'],
      'description': data['description'],
      'imageUrl': imageUrl,
      'location': data['location'],
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    // Actualizar reporte local
    final localReport = _localStorage.getReport(operation.reportId);
    if (localReport != null) {
      await _localStorage.saveReport(
        localReport.copyWith(isSynced: true, imageUrl: imageUrl)
      );
    }
  }

  // Sincronizar eliminación de reporte
  Future<void> _syncDeleteReport(PendingOperation operation) async {
    await _firestore.collection('reports').doc(operation.reportId).delete();
    await _localStorage.deleteReport(operation.reportId);
    await _localStorage.deleteLocalImage(operation.reportId);
  }

  // Sincronizar actualización de estado
  Future<void> _syncUpdateStatus(PendingOperation operation) async {
    final data = operation.data;
    await _firestore.collection('reports').doc(operation.reportId).update({
      'status': data['status'],
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    // Actualizar reporte local
    final localReport = _localStorage.getReport(operation.reportId);
    if (localReport != null) {
      await _localStorage.saveReport(
        localReport.copyWith(
          isSynced: true,
          status: data['status'] as String,
        )
      );
    }
  }

  // Descargar reportes más recientes de Firebase
  Future<void> _downloadLatestReports() async {
    try {
      final snapshot = await _firestore
          .collection('reports')
          .orderBy('createdAt', descending: true)
          .limit(100) 
          .get();

      await _updateLocalCache(snapshot.docs);
    } catch (e) {
      'Error al descargar reportes: $e';
    }
  }

  // Iniciar sincronización periódica (cada 10 segundos)
  void _startPeriodicSync() {
    _stopPeriodicSync(); 
    
    _periodicSyncTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (_connectivity.hasConnection) {
        final pendingOps = _localStorage.getPendingOperations();
        if (pendingOps.isNotEmpty) {
          await syncAll();
        }
      }
    });
  }

  // Detener sincronización periódica
  void _stopPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
  }

  // Disponer recursos
  void dispose() {
    _connectivitySubscription?.cancel();
    _reportsSubscription?.cancel();
    _syncStatusController.close();
    _stopPeriodicSync();
  }
}

// Estados de sincronización
enum SyncStatus {
  idle,
  syncing,
  synced,
  error,
  offline,
}

