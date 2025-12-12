import 'package:flutter/material.dart';
import 'dart:async';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'register_screen.dart';
import 'home_screen.dart';
import 'vendor_home_screen.dart';
import 'device_owner_setup_screen.dart';
import '../services/device_owner_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter/services.dart'; // Ya debería estar
import '../services/lock_polling_service.dart'; // Agregar esta línea si no está

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usuarioController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  
  // Variables para detectar 13 taps
  int _tapCount = 0;
  Timer? _tapTimer;

  @override
  void dispose() {
    _usuarioController.dispose();
    _passwordController.dispose();
    _tapTimer?.cancel();
    super.dispose();
  }

  void _handleTap() {
    _tapCount++;
    
    // Reiniciar contador después de 3 segundos de inactividad
    _tapTimer?.cancel();
    _tapTimer = Timer(const Duration(seconds: 3), () {
      setState(() => _tapCount = 0);
    });
    
    if (_tapCount == 13) {
      _tapCount = 0;
      _tapTimer?.cancel();
      
      // Navegar a Device Owner Setup
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const DeviceOwnerSetupScreen(),
        ),
      );
    }
  }

Future<void> _login() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() => _isLoading = true);

  final result = await _authService.login(
    usuario: _usuarioController.text.trim(),
    password: _passwordController.text,
  );

  if (!mounted) return;
  
  setState(() => _isLoading = false);

  if (result['success']) {
    final user = result['user'] as UserModel;
    
if (user.isVendedor) {
  print('🔍 Vendedor detectado, verificando bloqueo...');
  
  final deviceOwnerService = DeviceOwnerService();
  final lockStatus = await deviceOwnerService.checkLockStatus();
  
  print('📊 Estado de bloqueo: $lockStatus');
  
  // ✅ INICIAR SERVICIO DE MONITOREO NATIVO
  try {
    const platform = MethodChannel('com.example.security_app/device_owner');
    await platform.invokeMethod('startMonitorService');
    print('✅ Servicio de monitoreo iniciado');
  } catch (e) {
    print('❌ Error iniciando servicio: $e');
  }
  
  // ✅ INICIAR POLLING FLUTTER
  LockPollingService().startPolling();
  
  if (lockStatus['isLocked'] == true) {
    print('🔒 DISPOSITIVO BLOQUEADO - Activando bloqueo nativo');
    
    final message = lockStatus['lockMessage'] ?? 'Dispositivo bloqueado';
    final success = await deviceOwnerService.activateNativeLock(message);
    
    if (success) {
      print('✅ Bloqueo nativo activado exitosamente');
      SystemNavigator.pop();
      return;
    } else {
      print('❌ Error activando bloqueo nativo');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dispositivo bloqueado: $message. Error activando bloqueo.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _authService.logout();
      return;
    }
  } else {
    print('✅ Dispositivo NO bloqueado, permitiendo acceso');
  }
}

    // Solo si no está bloqueado o es dueño
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Redirigir según rol
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => user.isVendedor
            ? const VendorHomeScreen()
            : const HomeScreen(),
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
 @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1E40AF),
                Color(0xFF2563EB),
                Color(0xFF3B82F6),
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.security,
                          size: 80,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Título
                      const Text(
                        'BIENVENIDO A JCA',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Inicia sesión para continuar',
                        style: TextStyle(fontSize: 16, color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 50),

                      // Card con campos
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Campo Usuario
                            TextFormField(
                              controller: _usuarioController,
                              decoration: InputDecoration(
                                labelText: 'Usuario',
                                prefixIcon: const Icon(
                                  Icons.person_outline,
                                  color: Color(0xFF2563EB),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF2563EB),
                                    width: 2,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'El usuario es obligatorio';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // Campo Contraseña
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Contraseña',
                                prefixIcon: const Icon(
                                  Icons.lock_outline,
                                  color: Color(0xFF2563EB),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF2563EB),
                                    width: 2,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'La contraseña es obligatoria';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 30),

                            // Botón Login
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Iniciar Sesión',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Link a Registro
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            '¿No tienes cuenta?',
                            style: TextStyle(color: Colors.white70, fontSize: 15),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const RegisterScreen(),
                                ),
                              );
                            },
                            child: const Text(
                              'Regístrate',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}