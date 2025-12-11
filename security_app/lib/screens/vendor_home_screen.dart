import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../models/user_model.dart';
import '../models/linked_user_model.dart';
import '../services/auth_service.dart';
import '../services/link_service.dart';
import 'login_screen.dart';
import 'qr_display_screen.dart';

class VendorHomeScreen extends StatefulWidget {
  const VendorHomeScreen({super.key});

  @override
  State<VendorHomeScreen> createState() => _VendorHomeScreenState();
}

class _VendorHomeScreenState extends State<VendorHomeScreen> {
  final _authService = AuthService();
  final _linkService = LinkService();
  UserModel? _currentUser;
  bool _isLoading = true;
  
  // ✅ NUEVO: Para manejar solicitudes pendientes
  List<LinkRequest> _pendingRequests = [];
  Timer? _requestCheckTimer;
  bool _isDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _startRequestChecker();
  }

  Future<void> _loadUserData() async {
    _currentUser = await _authService.getUser();
    if (mounted) {
      setState(() => _isLoading = false);
    }
    _checkPendingRequests();
  }

  // ✅ NUEVO: Verificar solicitudes cada 30 segundos
  void _startRequestChecker() {
    _requestCheckTimer = Timer.periodic(
      const Duration(seconds: 30),
      (timer) => _checkPendingRequests(),
    );
  }

  // ✅ NUEVO: Revisar solicitudes pendientes
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

  // ✅ NUEVO: Mostrar diálogo de solicitud
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
                color: const Color(0xFF8B5CF6).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_add,
                color: Color(0xFF8B5CF6),
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
              'quiere vincularse contigo para compartir información.',
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
              Navigator.of(dialogContext).pop();
              
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
              Navigator.of(dialogContext).pop();
              
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
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
            ),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    return formatter.format(amount);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'No definido';
    return DateFormat('dd MMM yyyy').format(date);
  }

  int _getDaysUntilPayment(DateTime? date) {
    if (date == null) return 0;
    final now = DateTime.now();
    final difference = date.difference(now);
    return difference.inDays;
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

    final deuda = _currentUser?.deudaInfo;
    final porcentajePagado = deuda?.deudaTotal != null && deuda!.deudaTotal > 0
        ? (deuda.deudaTotal - deuda.deudaRestante) / deuda.deudaTotal
        : 0.0;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
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
                      const SizedBox(height: 10),
                      _buildDebtCard(deuda, porcentajePagado),
                      const SizedBox(height: 24),
                      _buildPaymentInfo(deuda),
                      const SizedBox(height: 24),
                      _buildQuickStats(deuda),
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
                    '¡Hola!',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _currentUser?.nombre ?? 'Vendedor',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
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
                icon: const Icon(Icons.logout, 
                  color: Colors.white, 
                  size: 28
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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

  Widget _buildDebtCard(DeudaInfo? deuda, double porcentaje) {
    final deudaRestante = deuda?.deudaRestante ?? 0;
    final deudaTotal = deuda?.deudaTotal ?? 0;
    final daysUntil = _getDaysUntilPayment(deuda?.proximoPago);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance_wallet, 
                color: Colors.white, 
                size: 24
              ),
              SizedBox(width: 12),
              Text(
                'Deuda Restante',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _formatCurrency(deudaRestante),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'de ${_formatCurrency(deudaTotal)}',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: porcentaje,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(porcentaje * 100).toStringAsFixed(0)}% pagado',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              if (daysUntil > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$daysUntil días para el pago',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentInfo(DeudaInfo? deuda) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Información de Pagos',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 20),
          _buildInfoRow(
            icon: Icons.calendar_today,
            label: 'Próximo Pago',
            value: _formatDate(deuda?.proximoPago),
            color: const Color(0xFF8B5CF6),
          ),
          const Divider(height: 24),
          _buildInfoRow(
            icon: Icons.payments,
            label: 'Monto de Cuota',
            value: _formatCurrency(deuda?.montoCuota ?? 0),
            color: const Color(0xFF10B981),
          ),
          const Divider(height: 24),
          _buildInfoRow(
            icon: Icons.history,
            label: 'Último Pago',
            value: _formatDate(deuda?.ultimoPago),
            color: const Color(0xFF6366F1),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(DeudaInfo? deuda) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Estadísticas',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.check_circle,
                label: 'Cuotas\nPagadas',
                value: '${deuda?.cuotasPagadas ?? 0}',
                color: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                icon: Icons.pending,
                label: 'Cuotas\nPendientes',
                value: '${deuda?.cuotasPendientes ?? 0}',
                color: const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: color,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
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
    _requestCheckTimer?.cancel();
    super.dispose();
  }
}