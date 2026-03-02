import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

/// Servicio para monitorear la conectividad a internet
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionStatusController = 
      StreamController<bool>.broadcast();

  bool _hasConnection = true;
  bool _isInitialized = false;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
 
  Stream<bool> get connectionStatus => _connectionStatusController.stream;

  bool get hasConnection => _hasConnection;

  // Inicializar el servicio
  Future<void> initialize() async {
    if (_isInitialized) {
      
      return;
    }

    await _checkRealConnection();
        
    _connectionStatusController.add(_hasConnection);

    _subscription = _connectivity.onConnectivityChanged.listen((results) async {
      
      await _checkRealConnection();
    });

    _isInitialized = true;
    
  }

  // Verificar si hay conexión a internet
  Future<void> _checkRealConnection() async {
    try {
      
      final results = await _connectivity.checkConnectivity();
      final hasNetworkInterface = results.isNotEmpty && 
          !results.contains(ConnectivityResult.none);

      if (!hasNetworkInterface) {
        
        _updateConnectionState(false);
        return;
      }
      final hasInternet = await _pingGoogle();
      
      _updateConnectionState(hasInternet);
      
    } catch (e) {
      'Error al verificar conexión: $e';
      _updateConnectionState(false);
    }
  }

  //Hacer ping a Google para verificar conexión REAL
  Future<bool> _pingGoogle() async {
    try {
      
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        debugPrint('Ping exitoso - HAY INTERNET');
        return true;
      }
      
      debugPrint('Ping falló - SIN INTERNET');
      return false;
    } on SocketException catch (_) {
      debugPrint('SocketException - SIN INTERNET');
      return false;
    } on TimeoutException catch (_) {
      debugPrint('Timeout - SIN INTERNET');
      return false;
    } catch (e) {
      debugPrint('Error en ping: $e - SIN INTERNET');
      return false;
    }
  }

  /// Actualizar el estado de conexión
  void _updateConnectionState(bool hasConnection) {
    final changed = hasConnection != _hasConnection;
    _hasConnection = hasConnection;
    
    _connectionStatusController.add(_hasConnection);
    
    if (changed) {
      debugPrint(_hasConnection 
          ? 'CONEXIÓN A INTERNET RESTAURADA' 
          : 'SIN CONEXIÓN A INTERNET');
    } else {
      debugPrint('Estado confirmado: ${_hasConnection ? "ONLINE (con internet)" : "OFFLINE (sin internet)"}');
    }
  }

  /// Verificar manualmente la conexión
  Future<bool> checkConnectionManually() async {
    debugPrint('🔄 Verificación manual de conexión a internet...');
    await _checkRealConnection();
    return _hasConnection;
  }

  /// Disponer recursos
  void dispose() {
    _subscription?.cancel();
    _connectionStatusController.close();
    _isInitialized = false;
  }
}
