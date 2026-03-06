import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';

// Handler para notificaciones en segundo plano
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  'Notificación en segundo plano: ${message.messageId}';
} 

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  // Inicializar el servicio de notificaciones
  Future<void> initialize() async {
    try {
      
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      await _requestPermissions();

      await _configureLocalNotifications();

      await _getAndSaveToken();

      _configureNotificationListeners();

    } catch (e) {
      'Error al inicializar NotificationService: $e';
    }
  }

  // Solicitar permisos de notificaciones
  Future<void> _requestPermissions() async {
    if (Platform.isIOS) {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
    }

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );
     'Permisos de notificación: ${settings.authorizationStatus}';
  }

  // Configurar notificaciones locales
  Future<void> _configureLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        
      },
    );

    // Canal de notificación para Android
    const androidChannel = AndroidNotificationChannel(
      'reports_channel',
      'Reportes Vecinales',
      description: 'Notificaciones de nuevos reportes',
      importance: Importance.high,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  // Obtener y guardar token FCM
  Future<void> _getAndSaveToken() async {
    try {
      _fcmToken = await _messaging.getToken();
      
      _messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
       
      });
    } catch (e) {
      'Error al obtener token: $e';
    }
  }

  // Guardar token del usuario en Firestore
  Future<void> saveUserToken(String userId) async {
    if (_fcmToken == null) return;

    try {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': _fcmToken,
        'tokenUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      'Error al guardar token: $e';
    }
  }

  // Eliminar token al cerrar sesión
  Future<void> removeUserToken(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': FieldValue.delete(),
      });
      
    } catch (e) {
      '❌ Error al eliminar token: $e';
    }
  }

  // Configurar listeners de notificaciones
  void _configureNotificationListeners() {
    // Cuando la app está en primer plano
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });

    // app en segundo plano
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      
    });
  }

  // Mostrar notificación local
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'reports_channel',
      'Reportes Vecinales',
      channelDescription: 'Notificaciones de nuevos reportes',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      notificationDetails,
      payload: message.data['reportId'],
    );
  }

  // Enviar notificación a todos los usuarios
  Future<void> sendReportNotificationToAll({
    required String reportId,
    required String reportTitle,
    required String reportType,
    required String creatorId,
  }) async {
    try {
      
      final usersSnapshot = await _firestore
          .collection('users')
          .where('fcmToken', isNotEqualTo: null)
          .get();

      final List<String> tokens = [];
      for (var doc in usersSnapshot.docs) {
        if (doc.id != creatorId && doc.data()['fcmToken'] != null) {
          tokens.add(doc.data()['fcmToken'] as String);
        }
      }

      if (tokens.isEmpty) {
        
        return;
      }

      // Crear notificación para guardar en Firestore
      await _firestore.collection('notifications').add({
        'reportId': reportId,
        'title': 'Nuevo Reporte: $reportType',
        'body': reportTitle,
        'tokens': tokens,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

    } catch (e) {
      'Error al enviar notificación: $e';
    
    }
  }
}