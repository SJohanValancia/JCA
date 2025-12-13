import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/vendor_home_screen.dart';
import 'services/auth_service.dart';
import 'models/user_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // ✅ VERIFICAR SI HAY SESIÓN ACTIVA
  final authService = AuthService();
  final isLoggedIn = await authService.isLoggedIn();
  UserModel? user;
  
  if (isLoggedIn) {
    user = await authService.getUser();
    print('✅ Sesión activa encontrada: ${user?.nombre}');
    
    // ✅ Si es vendedor, asegurar que el servicio esté corriendo
    if (user?.isVendedor == true) {
      try {
        const platform = MethodChannel('com.example.security_app/device_owner');
        await platform.invokeMethod('startMonitorService');
        print('✅ Servicio de monitoreo reiniciado');
      } catch (e) {
        print('❌ Error reiniciando servicio: $e');
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