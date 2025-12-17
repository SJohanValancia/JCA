import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class PaymentNotificationService {
  static final PaymentNotificationService _instance = PaymentNotificationService._internal();
  factory PaymentNotificationService() => _instance;
  PaymentNotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  final storage = const FlutterSecureStorage();

  static const String baseUrl = 'https://jca-labd.onrender.com';
  bool _isInitialized = false;

  // ✅ Inicializar notificaciones locales
  Future<void> initialize() async {
    if (_isInitialized) {
      print('⚠️ PaymentNotificationService ya inicializado');
      return;
    }

    print('🔔 Inicializando PaymentNotificationService...');

    try {
      // Inicializar timezone
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('America/Bogota'));

      // Configuración Android
      const androidSettings = AndroidInitializationSettings('@drawable/ic_notification');
      
      const initSettings = InitializationSettings(
        android: androidSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Crear canal de notificación
      const androidChannel = AndroidNotificationChannel(
        'payment_channel',
        'Recordatorios de Pago',
        description: 'Notificaciones sobre pagos pendientes',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      // ✅ CORRECCIÓN AQUÍ - Faltaba el < después del método
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);

      _isInitialized = true;
      print('✅ PaymentNotificationService inicializado');
    } catch (e) {
      print('❌ Error inicializando notificaciones: $e');
    }
  }

  // ✅ Verificar pagos pendientes con el backend
  Future<Map<String, dynamic>?> checkPaymentStatus() async {
    try {
      final token = await storage.read(key: 'token');
      if (token == null) {
        print('⚠️ No hay token de autenticación');
        return null;
      }

      print('🔍 Verificando estado de pagos con backend...');

      final response = await http.get(
        Uri.parse('$baseUrl/api/auth/check-my-payments'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Estado de pago recibido: $data');
        return data;
      } else {
        print('⚠️ Error del servidor: ${response.statusCode}');
      }

      return null;
    } catch (e) {
      print('❌ Error verificando pagos: $e');
      return null;
    }
  }

  // ✅ Mostrar notificación según tipo
  Future<void> showPaymentNotification(String type, Map<String, dynamic> deudaInfo) async {
    try {
      if (!_isInitialized) {
        print('⚠️ Servicio no inicializado, inicializando ahora...');
        await initialize();
      }

      final montoCuota = deudaInfo['montoCuota'] ?? 0;
      final proximoPago = deudaInfo['proximoPago'];
      
      String fechaPago = 'próximamente';
      if (proximoPago != null) {
        final fecha = DateTime.parse(proximoPago);
        fechaPago = '${fecha.day}/${fecha.month}/${fecha.year}';
      }

      String title = '';
      String body = '';
      
      switch (type) {
        case '2days':
          title = '⏰ Recordatorio de Pago';
          body = 'Tu cuota de \$$montoCuota vence en 2 días ($fechaPago). ¡No olvides tu pago!';
          break;
        case '1day':
          title = '⚠️ Pago Mañana';
          body = '¡Importante! Tu cuota de \$$montoCuota vence mañana ($fechaPago). Prepara tu pago.';
          break;
        case 'today':
          title = '🚨 Día de Pago';
          body = 'Hoy es el día de tu pago: \$$montoCuota. Por favor realiza tu pago lo antes posible.';
          break;
        default:
          print('⚠️ Tipo de notificación desconocido: $type');
          return;
      }

      const androidDetails = AndroidNotificationDetails(
        'payment_channel',
        'Recordatorios de Pago',
        channelDescription: 'Notificaciones sobre pagos pendientes',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@drawable/ic_notification',
      );

      const details = NotificationDetails(android: androidDetails);

      await _localNotifications.show(
        type.hashCode,
        title,
        body,
        details,
      );

      print('✅ Notificación mostrada: $title');
      print('📝 Mensaje: $body');
    } catch (e) {
      print('❌ Error mostrando notificación: $e');
    }
  }

  // ✅ Manejar tap en notificación
  void _onNotificationTapped(NotificationResponse response) {
    print('👆 Notificación tocada');
    // Aquí puedes navegar a la pantalla de pagos si quieres
  }

  // ✅ Verificar y mostrar notificación si corresponde
  Future<void> checkAndNotify() async {
    try {
      print('🔔 ========================================');
      print('🔔 Iniciando verificación de pagos...');
      
      final status = await checkPaymentStatus();
      
      if (status == null) {
        print('⚠️ No se pudo obtener estado de pagos');
        print('🔔 ========================================');
        return;
      }

      if (status['hasDebt'] != true) {
        print('ℹ️ Sin deuda pendiente');
        print('🔔 ========================================');
        return;
      }

      final daysUntil = status['daysUntilPayment'] ?? -1;
      print('📅 Días hasta el pago: $daysUntil');

      if (status['shouldNotify'] == true && status['notificationType'] != null) {
        final notifType = status['notificationType'];
        print('🔔 Debe mostrar notificación: $notifType');
        
        await showPaymentNotification(
          notifType,
          status['deudaInfo']
        );
      } else {
        print('ℹ️ No es momento de notificar');
      }
      
      print('🔔 ========================================');
    } catch (e) {
      print('❌ Error en checkAndNotify: $e');
      print('🔔 ========================================');
    }
  }
}