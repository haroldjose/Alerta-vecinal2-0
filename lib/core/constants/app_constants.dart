class AppConstants {
  // Dimensiones
  static const double inputWidth = 335.0;
  static const double inputHeight = 48.0;
  static const double borderRadius = 8.0;
  
  // Textos
  static const String appName = 'Alerta Vecinal';
  
  // Validaciones
  static const int minPasswordLength = 6;
  static const int minNameLength = 2;
  static const int minDescriptionLength = 10;
  static const int maxDescriptionPreview = 100;
  
  // Firebase Collections
  static const String usersCollection = 'users';
  static const String reportsCollection = 'reports';
  
  // Storage Paths
  static const String profileImagesPath = 'profile_images';
  static const String reportImagesPath = 'reports';
  
  // Notification Types
  static const String newReportNotification = 'new_report';
  static const String statusUpdateNotification = 'status_update';
}