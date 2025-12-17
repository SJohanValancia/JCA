import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/vendor_home_screen.dart';
import 'services/auth_service.dart';
import 'services/payment_notification_service.dart';
import 'models/user_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // ✅ INICIALIZAR SERVICIO DE NOTIFICACIONES
  await PaymentNotificationService().initialize();
  
  // ✅ VERIFICAR SI HAY SESIÓN ACTIVA
  final authService = AuthService();
  final isLoggedIn = await authService.isLoggedIn();
  UserModel? user;
  
  if (isLoggedIn) {
    user = await authService.getUser();
    print('✅ Sesión activa encontrada: ${user?.nombre}');
    
    // ✅ Si es vendedor, asegurar que servicios estén corriendo
    if (user?.isVendedor == true) {
      try {
        const platform = MethodChannel('com.example.security_app/device_owner');
        
        // Reiniciar servicios
        await platform.invokeMethod('startMonitorService');
        await platform.invokeMethod('startLocationService');
        await platform.invokeMethod('startLocationMonitor');
        await platform.invokeMethod('startPaymentMonitor');
        
        print('✅ Servicios reiniciados en main');
        
        // ✅ Verificar pagos inmediatamente
        await PaymentNotificationService().checkAndNotify();
        
      } catch (e) {
        print('❌ Error reiniciando servicios: $e');
      }
    }
  }
  
  runApp(MyApp(isLoggedIn: isLoggedIn, user: user));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  final UserModel? user;
  
  const MyApp({
    super.key, 
    required this.isLoggedIn,
    this.user,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JCA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(),
      ),
      home: _getInitialScreen(),
    );
  }
  
  Widget _getInitialScreen() {
    if (!isLoggedIn || user == null) {
      return const LoginScreen();
    }
    
    return user!.isVendedor 
        ? const VendorHomeScreen()
        : const HomeScreen();
  }
}