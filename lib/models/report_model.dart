import 'package:cloud_firestore/cloud_firestore.dart';

enum ProblemType {
  inseguridad,
  serviciosBasicos,
  contaminacion,
  convivencia,
}

enum ReportStatus {
  pendiente,
  enRevision,
  resuelto,
}

extension ProblemTypeExtension on ProblemType {
  String get displayName {
    switch (this) {
      case ProblemType.inseguridad:
        return 'Inseguridad';
      case ProblemType.serviciosBasicos:
        return 'Servicios Básicos';
      case ProblemType.contaminacion:
        return 'Contaminación';
      case ProblemType.convivencia:
        return 'Convivencia';
    }
  }

  String get value {
    return toString().split('.').last;
  }

  // Colores para cada tipo de problema
  int get borderColor {
    switch (this) {
      case ProblemType.inseguridad:
        return 0xFFE53E3E; // Rojo
      case ProblemType.serviciosBasicos:
        return 0xFFD69E2E; // Amarillo anaranjado
      case ProblemType.contaminacion:
        return 0xFF38A169; // Verde
      case ProblemType.convivencia:
        return 0xFF3182CE; // Azul
    }
  }

  static ProblemType fromString(String value) {
    return ProblemType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => ProblemType.inseguridad,
    );
  }
}

extension ReportStatusExtension on ReportStatus {
  String get displayName {
    switch (this) {
      case ReportStatus.pendiente:
        return 'Pendiente';
      case ReportStatus.enRevision:
        return 'En Revisión';
      case ReportStatus.resuelto:
        return 'Resuelto';
    }
  }

  String get value {
    return toString().split('.').last;
  }

  // Colores para cada estado
  int get color {
    switch (this) {
      case ReportStatus.pendiente:
        return 0xFFD69E2E; 
      case ReportStatus.enRevision:
        return 0xFF3182CE; 
      case ReportStatus.resuelto:
        return 0xFF38A169; 
    }
  }

  static ReportStatus fromString(String value) {
    return ReportStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => ReportStatus.pendiente,
    );
  }
}

class LocationData {
  final double latitude;
  final double longitude;
  final String? address;

  LocationData({
    required this.latitude,
    required this.longitude,
    this.address,
  });

  factory LocationData.fromMap(Map<String, dynamic> map) {
    return LocationData(
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      address: map['address'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
    };
  }

  String get coordinates => '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

  // Obtener URL para Google Maps
  String get googleMapsUrl => 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';

  // Obtener dirección o coordenadas
  String get displayText => address ?? coordinates;
}

class ReportModel {
  final String id;
  final String userId;
  final String userName;
  final ProblemType problemType;
  final ReportStatus status;
  final String title;
  final String description;
  final String? imageUrl;
  final LocationData? location;
  final DateTime createdAt;
  final DateTime updatedAt;

  ReportModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.problemType,
    required this.status,
    required this.title,
    required this.description,
    this.imageUrl,
    this.location,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReportModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReportModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      problemType: ProblemTypeExtension.fromString(data['problemType'] ?? ''),
      status: ReportStatusExtension.fromString(data['status'] ?? ''),
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'],
      location: data['location'] != null 
          ? LocationData.fromMap(data['location']) 
          : null,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'problemType': problemType.value,
      'status': status.value,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'location': location?.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  ReportModel copyWith({
    String? id,
    String? userId,
    String? userName,
    ProblemType? problemType,
    ReportStatus? status,
    String? title,
    String? description,
    String? imageUrl,
    LocationData? location,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReportModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      problemType: problemType ?? this.problemType,
      status: status ?? this.status,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Descripción truncada para cards
  String get truncatedDescription {
    if (description.length <= 100) return description;
    return '${description.substring(0, 97)}...';
  }
}