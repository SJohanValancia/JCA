import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class SimpleQRScreen extends StatelessWidget {
  const SimpleQRScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // ✅ URL que SIEMPRE apunta a la última versión
    const latestApkUrl = 
        "https://github.com/SJohanValancia/JCA/releases/latest/download/JCA.apk";

    return Scaffold(
      appBar: AppBar(
        title: const Text('Instalación JCA'),
        backgroundColor: Colors.blue[900],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  '📱 Descarga JCA',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Badge de versión
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green, width: 2),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Siempre la última versión',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 30),
              
              // QR Code
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.5),
                      spreadRadius: 5,
                      blurRadius: 7,
                    ),
                  ],
                ),
                child: QrImageView(
                  data: latestApkUrl,
                  version: QrVersions.auto,
                  size: 280.0,
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.H,
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Instrucciones
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue, width: 2),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📋 INSTRUCCIONES:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      '1️⃣ Escanea este QR con cualquier lector\n'
                      '2️⃣ Se descargará el APK de JCA\n'
                      '3️⃣ Instala la aplicación normalmente\n'
                      '4️⃣ Abre la app y sigue las instrucciones\n\n'
                      '💡 Este QR siempre descarga la versión más reciente',
                      style: TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Botón alternativo de descarga
              ElevatedButton.icon(
                onPressed: () {
                  // Copiar URL al portapapeles
                  _copyToClipboard(context, latestApkUrl);
                },
                icon: const Icon(Icons.link),
                label: const Text('Copiar enlace de descarga'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[900],
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    // Aquí usarías Clipboard.setData si quisieras copiar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Enlace: https://github.com/SJohanValancia/JCA/releases/latest/download/JCA.apk'),
        duration: Duration(seconds: 3),
      ),
    );
  }
}