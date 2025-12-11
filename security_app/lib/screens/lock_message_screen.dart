// lib/screens/lock_message_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../services/device_owner_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class LockMessageScreen extends StatefulWidget {
  final String message;
  final String lockedBy;
  final DateTime lockedAt;

  const LockMessageScreen({
    super.key,
    required this.message,
    required this.lockedBy,
    required this.lockedAt,
  });

  @override
  State<LockMessageScreen> createState() => _LockMessageScreenState();
}

class _LockMessageScreenState extends State<LockMessageScreen> {
  final _deviceOwnerService = DeviceOwnerService();
  final _authService = AuthService();
  Timer? _checkTimer;

  @override
  void initState() {
    super.initState();
    // Bloquear inmediatamente al cargar
    _activateNativeLock();
    // Verificar cada 10 segundos si fue desbloqueado
    _startCheckTimer();
  }

  void _startCheckTimer() {
    _checkTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkUnlockStatus();
    });
  }

  Future<void> _activateNativeLock() async {
    await _deviceOwnerService.activateNativeLock(widget.message);
  }

  Future<void> _checkUnlockStatus() async {
    final status = await _deviceOwnerService.checkLockStatus();
    
    if (status['isLocked'] == false) {
      // Desbloquear dispositivo nativo
      await _deviceOwnerService.deactivateNativeLock();
      
      if (mounted) {
        _checkTimer?.cancel();
        
        // Volver al login
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Dispositivo desbloqueado'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDate(DateTime dateTime) {
    final months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return '${dateTime.day} de ${months[dateTime.month - 1]} de ${dateTime.year}';
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Bloquear botón de atrás
      child: Scaffold(
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFEF4444),
                  Color(0xFFDC2626),
                  Color(0xFFB91C1C),
                ],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icono de bloqueo animado
                      TweenAnimationBuilder(
                        tween: Tween<double>(begin: 0.8, end: 1.0),
                        duration: const Duration(seconds: 2),
                        curve: Curves.easeInOut,
                        builder: (context, double value, child) {
                          return Transform.scale(
                            scale: value,
                            child: Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 30,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.lock,
                                size: 80,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 40),
                      
                      // Título
                      const Text(
                        'DISPOSITIVO BLOQUEADO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      
                      Container(
                        width: 60,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Mensaje principal
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.white,
                              size: 40,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              widget.message,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                height: 1.5,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                      
                      // Información de bloqueo
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            _buildInfoRow(
                              Icons.person_outline,
                              'Bloqueado por',
                              widget.lockedBy,
                            ),
                            const SizedBox(height: 12),
                            Divider(color: Colors.white.withOpacity(0.3)),
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              Icons.calendar_today,
                              'Fecha',
                              _formatDate(widget.lockedAt),
                            ),
                            const SizedBox(height: 12),
                            Divider(color: Colors.white.withOpacity(0.3)),
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              Icons.access_time,
                              'Hora',
                              _formatTime(widget.lockedAt),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                      
                      // Indicador de verificación
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Verificando estado...',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      // Mensaje informativo
                      Text(
                        'Este dispositivo será desbloqueado automáticamente\ncuando el administrador lo autorice.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 13,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }
}