import 'package:hive/hive.dart';
import 'report_model.dart';
import 'user_model.dart';

part 'local_models.g.dart';

  
// Adaptador para almacenar reportes en Hive
@HiveType(typeId: 0)
class LocalReportModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String userId;

  @HiveField(2)
  final String userName;

  @HiveField(3)
  final String problemType;

  @HiveField(4)
  final String status;

  @HiveField(5)
  final String title;

  @HiveField(6)
  final String description;

  @HiveField(7)
  final String? imageUrl;

  @HiveField(8)
  final String? localImagePath; // Ruta local de la imagen

  @HiveField(9)
  final double? latitude;

  @HiveField(10)
  final double? longitude;

  @HiveField(11)
  final String? address;

  @HiveField(12)
  final DateTime createdAt;

  @HiveField(13)
  final DateTime updatedAt;

  @HiveField(14)
  final bool isSynced; // Si está sincronizado con Firebase

  LocalReportModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.problemType,
    required this.status,
    required this.title,
    required this.description,
    this.imageUrl,
    this.localImagePath,
    this.latitude,
    this.longitude,
    this.address,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
  });

  // Convertir de ReportModel a LocalReportModel
  factory LocalReportModel.fromReportModel(ReportModel report, {bool isSynced = true}) {
    return LocalReportModel(
      id: report.id,
      userId: report.userId,
      userName: report.userName,
      problemType: report.problemType.value,
      status: report.status.value,
      title: report.title,
      description: report.description,
      imageUrl: report.imageUrl,
      latitude: report.location?.latitude,
      longitude: report.location?.longitude,
      address: report.location?.address,
      createdAt: report.createdAt,
      updatedAt: report.updatedAt,
      isSynced: isSynced,
    );
  }

  // Convertir de LocalReportModel a ReportModel
  ReportModel toReportModel() {
    LocationData? location;
    if (latitude != null && longitude != null) {
      location = LocationData(
        latitude: latitude!,
        longitude: longitude!,
        address: address,
      );
    }

    return ReportModel(
      id: id,
      userId: userId,
      userName: userName,
      problemType: ProblemTypeExtension.fromString(problemType),
      status: ReportStatusExtension.fromString(status),
      title: title,
      description: description,
      imageUrl: imageUrl,
      location: location,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  LocalReportModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? problemType,
    String? status,
    String? title,
    String? description,
    String? imageUrl,
    String? localImagePath,
    double? latitude,
    double? longitude,
    String? address,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
  }) {
    return LocalReportModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      problemType: problemType ?? this.problemType,
      status: status ?? this.status,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      localImagePath: localImagePath ?? this.localImagePath,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}

// Operaciones pendientes de sincronización
@HiveType(typeId: 1)
class PendingOperation extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String type; 

  @HiveField(2)
  final String reportId;

  @HiveField(3)
  final Map<String, dynamic> data;

  @HiveField(4)
  final DateTime timestamp;

  @HiveField(5)
  final int retryCount;

  PendingOperation({
    required this.id,
    required this.type,
    required this.reportId,
    required this.data,
    required this.timestamp,
    this.retryCount = 0,
  });

  PendingOperation copyWith({
    String? id,
    String? type,
    String? reportId,
    Map<String, dynamic>? data,
    DateTime? timestamp,
    int? retryCount,
  }) {
    return PendingOperation(
      id: id ?? this.id,
      type: type ?? this.type,
      reportId: reportId ?? this.reportId,
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}

// Adaptador para User (caché básico)
@HiveType(typeId: 2)
class LocalUserModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String email;

  @HiveField(3)
  final String role;

  @HiveField(4)
  final String? cargo;

  @HiveField(5)
  final String? profileImage;

  @HiveField(6)
  final DateTime createdAt;

  @HiveField(7)
  final String? cedula;    // 

  @HiveField(8)
  final String? username;  // 

  @HiveField(9)
  final String? celular;   //
  
  @HiveField(10)
  final bool notificationsEnabled; //switch maestro de notificaciones

  
  @HiveField(11)
  final bool notificationsAllCategories; // el usuario recibe notificaciones de todas las categorías.

  @HiveField(12)
  final List<String> notificationCategories; // lista de Strings con los values de las categorías seleccionadas.

  LocalUserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.cargo,
    this.profileImage,
    required this.createdAt,
    this.cedula,    // 
    this.username,  // 
    this.celular,   //
    this.notificationsEnabled = true,    //
    this.notificationsAllCategories = true, //
    this.notificationCategories = const [],  //
  });

  factory LocalUserModel.fromUserModel(UserModel user) {
    return LocalUserModel(
      id: user.id,
      name: user.name,
      email: user.email,
      role: UserModel.roleToString(user.role),
      cargo: user.cargo,
      profileImage: user.profileImage,
      createdAt: user.createdAt,
      cedula: user.cedula,       // 
      username: user.username,   // 
      celular: user.celular,     //
      notificationsEnabled: user.notificationPreferences.enabled, //
      notificationsAllCategories:
          user.notificationPreferences.allCategories,  //
      notificationCategories: user.notificationPreferences.selectedCategories
          .map((c) => c.value)
          .toList(),  //
    );
  }

  UserModel toUserModel() {
    return UserModel(
      id: id,
      name: name,
      email: email,
      role: UserModel.parseRole(role),
      cargo: cargo,
      profileImage: profileImage,
      createdAt: createdAt,
      cedula: cedula,     // 
      username: username, // 
      celular: celular,   //
      notificationPreferences: NotificationPreferences(   //
        enabled: notificationsEnabled,
        allCategories: notificationsAllCategories,
        selectedCategories: notificationCategories
            .map((s) => NotificationCategoryExtension.fromString(s))
            .toSet(),
      ),
    );
  }
}