import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/linked_user_model.dart';
import '../services/link_service.dart';
import '../services/auth_service.dart';
import 'debt_config_screen.dart';
import 'block_device_dialog.dart';
import '../services/device_owner_service.dart';
import '../services/app_protection_service.dart';
import 'login_screen.dart';

class LinkedDevicesScreen extends StatefulWidget {
  const LinkedDevicesScreen({super.key});

  @override
  State<LinkedDevicesScreen> createState() => _LinkedDevicesScreenState();
}

class _LinkedDevicesScreenState extends State<LinkedDevicesScreen> {
  final _linkService = LinkService();
  final _deviceOwnerService = DeviceOwnerService();
  final _appProtectionService = AppProtectionService();
  final _authService = AuthService();
  List<LinkedUserModel> _linkedDevices = [];
  bool _isLoading = true;
  final Map<String, bool> _lockStates = {};
  int _pinAttempts = 0;

  @override
  void initState() {
    super.initState();
    _loadLinkedDevices();
  }

  Future<void> _loadLinkedDevices() async {
    setState(() => _isLoading = true);
    
    final devices = await _linkService.getLinkedDevices();
    
    if (mounted) {
      setState(() {
        _linkedDevices = devices;
        _isLoading = false;
      });
      
      _loadLockStates();
    }
  }

  Future<void> _loadLockStates() async {
    for (var device in _linkedDevices) {
      if (device.isVendedor) {
        final status = await _deviceOwnerService.getLockStatus(device.id);
        if (mounted) {
          setState(() {
            _lockStates[device.id] = status['isLocked'] ?? false;
          });
        }
      }
    }
  }

  Future<void> _openDebtConfig(LinkedUserModel device) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DebtConfigScreen(vendedor: device),
      ),
    );

    if (result == true) {
      _loadLinkedDevices();
    }
  }

  Future<void> _showBlockDialog(LinkedUserModel device) async {
    await showDialog(
      context: context,
      builder: (context) => BlockDeviceDialog(vendedor: device),
    );
    
    _loadLockStates();
  }

  Future<void> _unlockDevice(LinkedUserModel device) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.lock_open, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text('Desbloquear Dispositivo'),
          ],
        ),
        content: Text(
          '¿Deseas desbloquear el dispositivo de ${device.nombre}?',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Desbloquear'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      print('🔓 Desbloqueando en backend...');
      
      final result = await _deviceOwnerService.unlockDevice(vendedorId: device.id);
      
      print('📡 Backend response: $result');
      
      if (mounted) {
        Navigator.pop(context);
        
        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Dispositivo desbloqueado\nEl bloqueo se quitará automáticamente en 3 segundos'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
          
          await Future.delayed(const Duration(seconds: 3));
          _loadLockStates();
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
  }

  Future<void> _unlinkDevice(LinkedUserModel device) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Desvincular Dispositivo'),
        content: Text(
          '¿Estás seguro de que deseas desvincular a ${device.nombre}?\n\n'
          'Dejarán de compartir ubicaciones.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Desvincular'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _linkService.unlinkDevice(device.id);
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dispositivo desvinculado'),
              backgroundColor: Colors.green,
            ),
          );
          _loadLinkedDevices();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al desvincular'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // ✅ NUEVO: Diálogo de liberación de app con PIN
Future<void> _showReleaseAppDialog(LinkedUserModel device) async {
  _pinAttempts = 0;
  final pinController = TextEditingController();
  
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => WillPopScope(
      onWillPop: () async => false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.security, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Liberar App',
                style: TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ingresa el PIN para liberar la app del dispositivo de:',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                device.nombre,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: InputDecoration(
                labelText: 'PIN de Seguridad',
                hintText: '0000',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.pin),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '⚠️ Después de liberar, el vendedor podrá desinstalar la app',
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              pinController.dispose();
              Navigator.of(dialogContext).pop(false);
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final pin = pinController.text.trim();
              
              if (pin == '0000') {
                // ✅ PIN correcto
                pinController.dispose();
                Navigator.of(dialogContext).pop(true);
              } else {
                // ❌ PIN incorrecto
                _pinAttempts++;
                
                if (_pinAttempts >= 3) {
                  // Cerrar sesión después de 3 intentos
                  pinController.dispose();
                  Navigator.of(dialogContext).pop(false);
                  
                  // ✅ Esperar un frame
                  await Future.delayed(const Duration(milliseconds: 100));
                  
                  if (mounted) {
                    await _authService.logout();
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('❌ 3 intentos fallidos. Sesión cerrada por seguridad.'),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 4),
                      ),
                    );
                    
                    // ✅ Esperar otro frame antes de navegar
                    await Future.delayed(const Duration(milliseconds: 100));
                    
                    if (mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                        (route) => false,
                      );
                    }
                  }
                } else {
                  // Mostrar error
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '❌ PIN incorrecto. Intento ${_pinAttempts}/3',
                      ),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  pinController.clear();
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    ),
  );
  
  // ✅ Si el PIN fue correcto, liberar la app
  if (result == true && mounted) {
    _releaseAppWithConfirmation(device);
  }
}
  // ✅ NUEVO: Confirmar y ejecutar liberación
Future<void> _releaseAppWithConfirmation(LinkedUserModel device) async {
  // ✅ Esperar un frame antes de mostrar el loading
  await Future.delayed(const Duration(milliseconds: 100));
  
  if (!mounted) return;
  
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (loadingContext) => WillPopScope(
      onWillPop: () async => false,
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    ),
  );
  
  print('🔓 Liberando app del dispositivo...');
  
  final success = await _appProtectionService.releaseApp(device.id);
  
  if (mounted) {
    // ✅ Cerrar el loading con Navigator.of(context, rootNavigator: true)
    Navigator.of(context, rootNavigator: true).pop();
    
    // ✅ Esperar un frame antes de mostrar el SnackBar
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ App liberada en el dispositivo de ${device.nombre}\n'
              'Ahora puede desinstalar la aplicación.',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Error al liberar la app'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispositivos Vinculados'),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)),
            )
          : _linkedDevices.isEmpty
              ? _buildEmptyState()
              : _buildDeviceList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.link_off,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'No tienes dispositivos vinculados',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Usa el botón "Unir" para vincular dispositivos y compartir ubicaciones',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceList() {
    return RefreshIndicator(
      onRefresh: _loadLinkedDevices,
      color: const Color(0xFF2563EB),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _linkedDevices.length,
        itemBuilder: (context, index) {
          final device = _linkedDevices[index];
          return _buildDeviceCard(device);
        },
      ),
    );
  }

  Widget _buildDeviceCard(LinkedUserModel device) {
    final isLocked = _lockStates[device.id] ?? false;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      child: Stack(
        children: [
          InkWell(
            onTap: () => _showDeviceDetails(device),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Color(0xFF2563EB),
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.nombre,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.badge, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              device.jcId,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (device.isVendedor) ...[
                    IconButton(
                      onPressed: () => _openDebtConfig(device),
                      icon: const Icon(Icons.settings, color: Color(0xFF8B5CF6)),
                      tooltip: 'Configurar deuda',
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isLocked ? Colors.green : Colors.red,
                          width: 2,
                        ),
                      ),
                      child: IconButton(
                        onPressed: () {
                          if (isLocked) {
                            _unlockDevice(device);
                          } else {
                            _showBlockDialog(device);
                          }
                        },
                        icon: Icon(
                          isLocked ? Icons.lock_open : Icons.lock,
                          color: isLocked ? Colors.green : Colors.red,
                        ),
                        tooltip: isLocked ? 'Desbloquear' : 'Bloquear',
                      ),
                    ),
                  ],
                  IconButton(
                    onPressed: () => _unlinkDevice(device),
                    icon: const Icon(Icons.link_off, color: Colors.red),
                    tooltip: 'Desvincular',
                  ),
                ],
              ),
            ),
          ),
          if (isLocked)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock, size: 12, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'BLOQUEADO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showDeviceDetails(LinkedUserModel device) {
    final isLocked = _lockStates[device.id] ?? false;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person,
                color: Color(0xFF2563EB),
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              device.nombre,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: device.jcId));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✓ JC-ID copiado'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      device.jcId,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.copy, size: 16),
                  ],
                ),
              ),
            ),
            if (isLocked) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text(
                      'DISPOSITIVO BLOQUEADO',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            _buildInfoRow(
              Icons.person_outline,
              'Usuario',
              '@${device.usuario}',
            ),
            const SizedBox(height: 24),
            
            if (device.isVendedor) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showReleaseAppDialog(device);
                  },
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Liberar App del Dispositivo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _unlinkDevice(device);
                },
                icon: const Icon(Icons.link_off),
                label: const Text('Desvincular Dispositivo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF2563EB), size: 20),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}