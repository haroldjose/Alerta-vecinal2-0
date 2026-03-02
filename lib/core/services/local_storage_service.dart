import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/local_models.dart';
import '../../models/report_model.dart';

/// Servicio para manejar el almacenamiento local con Hive
class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  // Nombres de las cajas de Hive
  static const String _reportsBox = 'reports';
  static const String _pendingOpsBox = 'pending_operations';
  static const String _usersBox = 'users';
  static const String _imagesBox = 'local_images';

  bool _initialized = false;

  /// Inicializar Hive y registrar adaptadores
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Inicializar Hive
      await Hive.initFlutter();

      // Registrar adaptadores
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(LocalReportModelAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(PendingOperationAdapter());
      }
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(LocalUserModelAdapter());
      }

      // Abrir las cajas
      await Hive.openBox<LocalReportModel>(_reportsBox);
      await Hive.openBox<PendingOperation>(_pendingOpsBox);
      await Hive.openBox<LocalUserModel>(_usersBox);
      await Hive.openBox<String>(_imagesBox); 
      _initialized = true;
      
    } catch (e) {
      'Error al inicializar LocalStorageService: $e';
      rethrow;
    }
  }

  // Guardar o actualizar un reporte local
  Future<void> saveReport(LocalReportModel report) async {
    final box = Hive.box<LocalReportModel>(_reportsBox);
    await box.put(report.id, report);
  }

  // Obtener un reporte por ID
  LocalReportModel? getReport(String id) {
    final box = Hive.box<LocalReportModel>(_reportsBox);
    return box.get(id);
  }

  // Obtener todos los reportes
  List<LocalReportModel> getAllReports() {
    final box = Hive.box<LocalReportModel>(_reportsBox);
    return box.values.toList();
  }

  // Obtener reportes del usuario
  List<LocalReportModel> getReportsByUser(String userId) {
    final box = Hive.box<LocalReportModel>(_reportsBox);
    return box.values.where((r) => r.userId == userId).toList();
  }

  // Obtener reportes por tipo
  List<LocalReportModel> getReportsByType(ProblemType type) {
    final box = Hive.box<LocalReportModel>(_reportsBox);
    return box.values.where((r) => r.problemType == type.value).toList();
  }

  // Obtener reportes no sincronizados
  List<LocalReportModel> getUnsyncedReports() {
    final box = Hive.box<LocalReportModel>(_reportsBox);
    return box.values.where((r) => !r.isSynced).toList();
  }

  // Eliminar un reporte
  Future<void> deleteReport(String id) async {
    final box = Hive.box<LocalReportModel>(_reportsBox);
    await box.delete(id);
  }

  // Limpiar todos los reportes
  Future<void> clearReports() async {
    final box = Hive.box<LocalReportModel>(_reportsBox);
    await box.clear();
  }

  // Agregar operación pendiente
  Future<void> addPendingOperation(PendingOperation operation) async {
    final box = Hive.box<PendingOperation>(_pendingOpsBox);
    await box.put(operation.id, operation);
  }

  // Obtener todas las operaciones pendientes
  List<PendingOperation> getPendingOperations() {
    final box = Hive.box<PendingOperation>(_pendingOpsBox);
    final ops = box.values.toList();
    ops.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return ops;
  }

  // Eliminar operación pendiente
  Future<void> removePendingOperation(String id) async {
    final box = Hive.box<PendingOperation>(_pendingOpsBox);
    await box.delete(id);
  }

  // Actualizar contador de reintentos
  Future<void> updateOperationRetryCount(String id, int retryCount) async {
    final box = Hive.box<PendingOperation>(_pendingOpsBox);
    final operation = box.get(id);
    if (operation != null) {
      final updated = operation.copyWith(retryCount: retryCount);
      await box.put(id, updated);
    }
  }

  // Limpiar operaciones pendientes
  Future<void> clearPendingOperations() async {
    final box = Hive.box<PendingOperation>(_pendingOpsBox);
    await box.clear();
  }

  // Guardar imagen local y retornar su ruta
  Future<String> saveLocalImage(File imageFile, String reportId) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${directory.path}/report_images');
      
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final fileName = '${reportId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final localPath = '${imagesDir.path}/$fileName';
      
      await imageFile.copy(localPath);

      final box = Hive.box<String>(_imagesBox);
      await box.put(reportId, localPath);

      return localPath;
    } catch (e) {
      'Error al guardar imagen local: $e';
      rethrow;
    }
  }

  // Obtener ruta de imagen local
  String? getLocalImagePath(String reportId) {
    final box = Hive.box<String>(_imagesBox);
    return box.get(reportId);
  }

  // Eliminar imagen local
  Future<void> deleteLocalImage(String reportId) async {
    try {
      final box = Hive.box<String>(_imagesBox);
      final path = box.get(reportId);
      
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
        await box.delete(reportId);
       
      }
    } catch (e) {
      'Error al eliminar imagen local: $e';
    }
  }

  Future<void> saveUser(LocalUserModel user) async {
    final box = Hive.box<LocalUserModel>(_usersBox);
    await box.put(user.id, user);
  }

  LocalUserModel? getUser(String id) {
    final box = Hive.box<LocalUserModel>(_usersBox);
    return box.get(id);
  }

  // Cerrar todas las cajas
  Future<void> closeAll() async {
    await Hive.close();
  }

  // Limpiar toda la base de datos local
  Future<void> clearAll() async {
    await clearReports();
    await clearPendingOperations();
    
    final usersBox = Hive.box<LocalUserModel>(_usersBox);
    await usersBox.clear();
    
    final imagesBox = Hive.box<String>(_imagesBox);
    await imagesBox.clear();
    
  }
}