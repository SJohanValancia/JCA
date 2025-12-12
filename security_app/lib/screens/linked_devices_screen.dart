import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/linked_user_model.dart';
import '../services/link_service.dart';
import 'debt_config_screen.dart';
import 'block_device_dialog.dart';
import '../services/device_owner_service.dart';

class LinkedDevicesScreen extends StatefulWidget {
  const LinkedDevicesScreen({super.key});

  @override
  State<LinkedDevicesScreen> createState() => _LinkedDevicesScreenState();
}

class _LinkedDevicesScreenState extends State<LinkedDevicesScreen> {
  final _linkService = LinkService();
  final _deviceOwnerService = DeviceOwnerService();
  List<LinkedUserModel> _linkedDevices = [];
  bool _isLoading = true;
  final Map<String, bool> _lockStates = {};

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
      
      // Cargar estados de bloqueo
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
    
    // Recargar estados después de bloquear
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
      child: InkWell(
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            device.nombre,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isLocked)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock, size: 14, color: Colors.red),
                                SizedBox(width: 4),
                                Text(
                                  'Bloqueado',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
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
              // Botones de acción solo para vendedores
              if (device.isVendedor) ...[
                // Botón de configuración de deuda
                IconButton(
                  onPressed: () => _openDebtConfig(device),
                  icon: const Icon(Icons.settings, color: Color(0xFF8B5CF6)),
                  tooltip: 'Configurar deuda',
                ),
                // Botón de bloqueo/desbloqueo
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
              // Botón de desvincular
              IconButton(
                onPressed: () => _unlinkDevice(device),
                icon: const Icon(Icons.link_off, color: Colors.red),
                tooltip: 'Desvincular',
              ),
            ],
          ),
        ),
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