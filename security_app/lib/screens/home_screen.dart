import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user_model.dart';
import '../models/linked_user_model.dart';
import '../services/auth_service.dart';
import '../services/device_service.dart';
import '../services/permission_service.dart';
import '../services/link_service.dart';
import 'map_screen.dart';
import 'login_screen.dart';
import 'linked_devices_screen.dart';
import 'emergency_contacts_screen.dart';
import 'qr_scanner_screen.dart';
import 'qr_display_screen.dart';
import 'dart:async';
import 'vendor_home_screen.dart';
import 'qr_provisioning_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  final _deviceService = DeviceService();
  final _permissionService = PermissionService();
  final _linkService = LinkService();
  UserModel? _currentUser;
  bool _isLoading = true;
  List<LinkRequest> _pendingRequests = [];
  Timer? _requestCheckTimer;
  bool _isDialogOpen = false;
  
  // ✅ NUEVO: MethodChannel para comunicarse con Kotlin
  static const platform = MethodChannel('com.example.security_app/device_owner');

  @override
  void initState() {
    super.initState();
    _initializeApp();
    _startRequestChecker();
  }

Future<void> _initializeApp() async {
  _currentUser = await _authService.getUser();
  
  // ✅ Redirigir si es vendedor
  if (_currentUser?.isVendedor == true && mounted) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const VendorHomeScreen(),
      ),
    );
    return;
  }
  
  if (mounted) {
    setState(() => _isLoading = false);
  }

  _backgroundTasks();
  _checkPendingRequests();
}

  void _backgroundTasks() {
    _deviceService.saveDeviceToBackend();
    _permissionService.requestPermissions(context);
  }

  void _startRequestChecker() {
    _requestCheckTimer = Timer.periodic(
      const Duration(seconds: 30),
      (timer) => _checkPendingRequests(),
    );
  }

  Future<void> _checkPendingRequests() async {
    if (_isDialogOpen) return;
    
    final requests = await _linkService.getPendingRequests();
    if (mounted) {
      setState(() {
        _pendingRequests = requests;
      });
      
      if (requests.isNotEmpty && !_isDialogOpen) {
        _isDialogOpen = true;
        _showLinkRequestDialog(requests.first);
      }
    }
  }

  // ✅ NUEVO: Activar depuración USB
  Future<void> _enableUSBDebugging() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Activar Depuración USB'),
          ],
        ),
        content: const Text(
          '¿Estás seguro?\n\n'
          'Esto habilitará:\n'
          '• Depuración USB\n'
          '• Opciones de desarrollador\n'
          '• Actualizaciones via ADB\n\n'
          'Solo hazlo si necesitas actualizar la app.',
          style: TextStyle(fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Mostrar loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );
              
              try {
                final result = await platform.invokeMethod('releaseApp', {
                  'vendorId': 'manual_unlock',
                });
                
                if (mounted) {
                  Navigator.pop(context); // Cerrar loading
                  
                  if (result == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Depuración USB habilitada\n'
                            'Ahora puedes actualizar via ADB'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 4),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('❌ Error al habilitar depuración'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context); // Cerrar loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Activar'),
          ),
        ],
      ),
    );
  }

void _showLinkRequestDialog(LinkRequest request) {
  if (_pendingRequests.isEmpty) return;
  
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_add,
              color: Color(0xFF2563EB),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Solicitud de Vinculación',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            request.nombre,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              request.jcId,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'quiere vincularse contigo para compartir ubicaciones en tiempo real.',
            style: TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 8),
          const Text(
            '¿Aceptas?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            // ✅ Cerrar diálogo principal primero
            Navigator.of(dialogContext).pop();
            
            // ✅ Mostrar loading en el scaffold context
            if (!mounted) return;
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (loadingContext) => WillPopScope(
                onWillPop: () async => false,
                child: const Center(child: CircularProgressIndicator()),
              ),
            );
            
            final success = await _linkService.respondToRequest(request.id, false);
            
            // ✅ Cerrar loading de forma segura
            if (mounted) {
              Navigator.of(context, rootNavigator: true).pop();
              
              if (success) {
                setState(() {
                  _isDialogOpen = false;
                  _pendingRequests.removeWhere((r) => r.id == request.id);
                });
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('❌ Solicitud rechazada'),
                    backgroundColor: Colors.orange,
                  ),
                );
                
                // Mostrar siguiente solicitud si existe
                if (_pendingRequests.isNotEmpty) {
                  await Future.delayed(const Duration(milliseconds: 500));
                  if (mounted) _showLinkRequestDialog(_pendingRequests.first);
                }
              }
            }
          },
          child: const Text(
            'Rechazar',
            style: TextStyle(color: Colors.red),
          ),
        ),
        ElevatedButton(
          onPressed: () async {
            // ✅ Cerrar diálogo principal primero
            Navigator.of(dialogContext).pop();
            
            // ✅ Mostrar loading en el scaffold context
            if (!mounted) return;
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (loadingContext) => WillPopScope(
                onWillPop: () async => false,
                child: const Center(child: CircularProgressIndicator()),
              ),
            );
            
            final success = await _linkService.respondToRequest(request.id, true);
            
            // ✅ Cerrar loading de forma segura
            if (mounted) {
              Navigator.of(context, rootNavigator: true).pop();
              
              if (success) {
                setState(() {
                  _isDialogOpen = false;
                  _pendingRequests.removeWhere((r) => r.id == request.id);
                });
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ ${request.nombre} vinculado exitosamente'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 3),
                  ),
                );
                
                // Mostrar siguiente solicitud si existe
                if (_pendingRequests.isNotEmpty) {
                  await Future.delayed(const Duration(milliseconds: 500));
                  if (mounted) _showLinkRequestDialog(_pendingRequests.first);
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('❌ Error al vincular'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
          ),
          child: const Text('Aceptar'),
        ),
      ],
    ),
  );
}
  
  // ✅ NUEVO: Escanear QR para vincular
  Future<void> _scanQRToLink() async {
    final scannedData = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const QRScannerScreen(),
      ),
    );

    if (scannedData == null || !mounted) return;

    // Validar que sea un JC-ID válido
    if (!scannedData.startsWith('JC')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Código QR inválido'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (loadingContext) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final result = await _linkService.sendLinkRequest(scannedData);

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();

      if (result['success']) {
        showDialog(
          context: context,
          builder: (successContext) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 12),
                Text('Solicitud Enviada'),
              ],
            ),
            content: Text(
              'Solicitud enviada a ${result['targetUser']['nombre']}.\n\n'
              'Espera a que acepte la vinculación.',
              style: const TextStyle(fontSize: 15),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(successContext),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.emergency, color: Color(0xFFEF4444), size: 28),
            SizedBox(width: 12),
            Text('Reportar Emergencia'),
          ],
        ),
        content: const Text(
          'Esta función estará disponible próximamente.\n\n'
          'Podrás reportar situaciones de emergencia con tu ubicación en tiempo real.',
          style: TextStyle(fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF2563EB)),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E40AF), Color(0xFF2563EB)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 20),
                      _buildMainReportButton(),
                      const SizedBox(height: 40),
                      _buildOptionsGrid(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

Widget _buildHeader() {
  return Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bienvenido!',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentUser?.nombre ?? 'Usuario',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            // ✅ ROW con los 3 botones
            Row(
              children: [
                // ✅ NUEVO: Botón para activar depuración
                IconButton(
                  onPressed: _enableUSBDebugging,
                  icon: const Icon(Icons.developer_mode, color: Colors.orange, size: 28),
                  tooltip: 'Activar Depuración USB',
                ),
                // Botón QR Provisioning
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SimpleQRScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.qr_code_2, color: Colors.white, size: 28),
                  tooltip: 'QR Device Owner',
                ),
                // Botón Logout
                IconButton(
                  onPressed: () async {
                    await _authService.logout();
                    if (mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.logout, color: Colors.white, size: 28),
                  tooltip: 'Cerrar sesión',
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        // ✅ QR en lugar de copiar ID
        GestureDetector(
          onTap: () {
            if (_currentUser?.jcId != null && _currentUser!.jcId.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => QRDisplayScreen(
                    jcId: _currentUser!.jcId,
                    nombre: _currentUser!.nombre,
                  ),
                ),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.qr_code, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'ID: ${_currentUser?.jcId ?? "N/A"}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.touch_app, color: Colors.white70, size: 16),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildMainReportButton() {
    return InkWell(
      onTap: _showReportDialog,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEF4444).withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.emergency, size: 60, color: Colors.white),
              SizedBox(height: 16),
              Text(
                'REPORTAR',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Emergencia o Situación de Riesgo',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Opciones Rápidas',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 20),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.1,
          children: [
            _buildOptionCard(
              icon: Icons.map_outlined,
              title: 'Mapa',
              subtitle: 'Ver ubicación',
              color: const Color(0xFF2563EB),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MapScreen()),
                );
              },
            ),
            _buildOptionCard(
              icon: Icons.qr_code_scanner,
              title: 'Escanear',
              subtitle: 'Vincular con QR',
              color: const Color(0xFF10B981),
              badge: _pendingRequests.isNotEmpty ? _pendingRequests.length : null,
              onTap: _scanQRToLink,
            ),
            _buildOptionCard(
              icon: Icons.people_outlined,
              title: 'Vinculados',
              subtitle: 'Dispositivos',
              color: const Color(0xFF8B5CF6),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LinkedDevicesScreen(),
                  ),
                );
              },
            ),
            _buildOptionCard(
              icon: Icons.contacts_outlined,
              title: 'Emergencias',
              subtitle: 'Contactos',
              color: const Color(0xFFEF4444),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EmergencyContactsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    int? badge,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 36, color: color),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            if (badge != null && badge > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badge.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _requestCheckTimer?.cancel();
    super.dispose();
  }
}