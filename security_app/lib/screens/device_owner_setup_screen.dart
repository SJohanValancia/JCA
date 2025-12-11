import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DeviceOwnerSetupScreen extends StatelessWidget {
  const DeviceOwnerSetupScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurar Device Owner'),
        backgroundColor: Colors.blue[900],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🔐 Establecer como Device Owner',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange, width: 2),
              ),
              child: const Text(
                '⚠️ REQUISITOS:\n\n'
                '• Dispositivo sin cuentas Google\n'
                '• No debe tener otras apps de Device Admin\n'
                '• Depuración USB habilitada',
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
            ),
            
            const SizedBox(height: 30),
            
            const Text(
              'Paso 1: Habilita depuración USB',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              '1. Ve a Ajustes → Acerca del teléfono\n'
              '2. Toca 7 veces en "Número de compilación"\n'
              '3. Vuelve a Ajustes → Opciones de desarrollador\n'
              '4. Activa "Depuración USB"',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
            
            const SizedBox(height: 30),
            
            const Text(
              'Paso 2: Ejecuta este comando desde tu PC',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'adb shell dpm set-device-owner com.example.security_app/.MyDeviceAdminReceiver',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(const ClipboardData(
                        text: 'adb shell dpm set-device-owner com.example.security_app/.MyDeviceAdminReceiver'
                      ));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Comando copiado al portapapeles')),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copiar comando'),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue, width: 2),
              ),
              child: const Text(
                '💡 ALTERNATIVA SIN PC:\n\n'
                'Si tienes root en el dispositivo, puedes ejecutar:\n'
                'su\n'
                'dpm set-device-owner com.example.security_app/.MyDeviceAdminReceiver',
                style: TextStyle(fontSize: 12, height: 1.5),
              ),
            ),
            
            const SizedBox(height: 30),
            
            ElevatedButton(
              onPressed: () {
                _checkDeviceOwnerStatus(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text(
                'Verificar estado de Device Owner',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _checkDeviceOwnerStatus(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Verificando... Implementa la verificación con tu DevicePolicyManager'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}