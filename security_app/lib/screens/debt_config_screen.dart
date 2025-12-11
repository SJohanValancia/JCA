import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/linked_user_model.dart';
import '../models/debt_config_model.dart';
import '../services/link_service.dart';

class DebtConfigScreen extends StatefulWidget {
  final LinkedUserModel vendedor;

  const DebtConfigScreen({super.key, required this.vendedor});

  @override
  State<DebtConfigScreen> createState() => _DebtConfigScreenState();
}

class _DebtConfigScreenState extends State<DebtConfigScreen> {
  final _linkService = LinkService();
  final _formKey = GlobalKey<FormState>();
  
  final _deudaTotalController = TextEditingController();
  final _numeroCuotasController = TextEditingController();
  final _montoCuotaController = TextEditingController();
  
  String _modalidadPago = 'mensual';
  List<int> _diasSeleccionados = [];
  bool _isLoading = true;
  bool _isSaving = false;
  DebtConfig? _currentConfig;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  Future<void> _loadCurrentConfig() async {
    setState(() => _isLoading = true);
    
    final config = await _linkService.getDebtConfig(widget.vendedor.id);
    
    if (mounted) {
      if (config != null) {
        setState(() {
          _currentConfig = config;
          _deudaTotalController.text = config.deudaTotal.toStringAsFixed(0);
          _numeroCuotasController.text = config.numeroCuotas.toString();
          _montoCuotaController.text = config.montoCuota.toStringAsFixed(0);
          _modalidadPago = config.modalidadPago;
          _diasSeleccionados = List.from(config.diasPago);
        });
      }
      setState(() => _isLoading = false);
    }
  }

  void _calcularMontoCuota() {
    final deudaTotal = double.tryParse(_deudaTotalController.text) ?? 0;
    final numeroCuotas = int.tryParse(_numeroCuotasController.text) ?? 0;
    
    if (deudaTotal > 0 && numeroCuotas > 0) {
      final montoCuota = deudaTotal / numeroCuotas;
      _montoCuotaController.text = montoCuota.toStringAsFixed(0);
    }
  }

  Future<void> _saveConfiguration() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_diasSeleccionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Debes seleccionar al menos un día de pago'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final debtConfig = DebtConfig(
      deudaTotal: double.parse(_deudaTotalController.text),
      numeroCuotas: int.parse(_numeroCuotasController.text),
      montoCuota: double.parse(_montoCuotaController.text),
      modalidadPago: _modalidadPago,
      diasPago: _diasSeleccionados,
      fechaInicio: DateTime.now(),
    );

    final result = await _linkService.configureDebt(
      linkedUserId: widget.vendedor.id,
      debtConfig: debtConfig,
    );

    if (mounted) {
      setState(() => _isSaving = false);

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Configuración guardada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${result['message']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Ajustes de Vinculación'),
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF2563EB)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes de Vinculación'),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildVendedorCard(),
            const SizedBox(height: 24),
            _buildDeudaTotalField(),
            const SizedBox(height: 16),
            _buildNumeroCuotasField(),
            const SizedBox(height: 16),
            _buildMontoCuotaField(),
            const SizedBox(height: 24),
            _buildModalidadPagoSection(),
            const SizedBox(height: 24),
            _buildDiasPagoSection(),
            const SizedBox(height: 32),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildVendedorCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.vendedor.nombre,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.vendedor.jcId,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeudaTotalField() {
    return TextFormField(
      controller: _deudaTotalController,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: 'Deuda Total',
        prefixIcon: const Icon(Icons.attach_money, color: Color(0xFF2563EB)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Ingresa la deuda total';
        }
        if (double.tryParse(value) == null || double.parse(value) <= 0) {
          return 'Ingresa un monto válido';
        }
        return null;
      },
      onChanged: (_) => _calcularMontoCuota(),
    );
  }

  Widget _buildNumeroCuotasField() {
    return TextFormField(
      controller: _numeroCuotasController,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: 'Número de Cuotas',
        prefixIcon: const Icon(Icons.format_list_numbered, color: Color(0xFF2563EB)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Ingresa el número de cuotas';
        }
        if (int.tryParse(value) == null || int.parse(value) <= 0) {
          return 'Ingresa un número válido';
        }
        return null;
      },
      onChanged: (_) => _calcularMontoCuota(),
    );
  }

  Widget _buildMontoCuotaField() {
    return TextFormField(
      controller: _montoCuotaController,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: 'Monto por Cuota',
        prefixIcon: const Icon(Icons.payments, color: Color(0xFF10B981)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
        ),
        helperText: 'Se calcula automáticamente, pero es editable',
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Ingresa el monto de cuota';
        }
        if (double.tryParse(value) == null || double.parse(value) <= 0) {
          return 'Ingresa un monto válido';
        }
        return null;
      },
    );
  }

  Widget _buildModalidadPagoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Modalidad de Pago',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildModalidadChip('Diario', 'diario', Icons.today),
            _buildModalidadChip('Semanal', 'semanal', Icons.date_range),
            _buildModalidadChip('Quincenal', 'quincenal', Icons.calendar_view_week),
            _buildModalidadChip('Mensual', 'mensual', Icons.calendar_month),
          ],
        ),
      ],
    );
  }

  Widget _buildModalidadChip(String label, String value, IconData icon) {
    final isSelected = _modalidadPago == value;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: isSelected ? Colors.white : const Color(0xFF2563EB)),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _modalidadPago = value;
          _diasSeleccionados.clear();
          // Auto-seleccionar para diario
          if (value == 'diario') {
            _diasSeleccionados = [1];
          }
        });
      },
      selectedColor: const Color(0xFF2563EB),
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF2563EB),
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildDiasPagoSection() {
    if (_modalidadPago == 'diario') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFF2563EB)),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Pago diario: Todos los días',
                style: TextStyle(
                  color: Color(0xFF2563EB),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Días de Pago',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        if (_modalidadPago == 'semanal') _buildDiasSemana(),
        if (_modalidadPago == 'quincenal') _buildDiasQuincena(),
        if (_modalidadPago == 'mensual') _buildDiasMes(),
      ],
    );
  }

  Widget _buildDiasSemana() {
    final dias = [
      {'value': 1, 'label': 'Lun'},
      {'value': 2, 'label': 'Mar'},
      {'value': 3, 'label': 'Mié'},
      {'value': 4, 'label': 'Jue'},
      {'value': 5, 'label': 'Vie'},
      {'value': 6, 'label': 'Sáb'},
      {'value': 0, 'label': 'Dom'},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: dias.map((dia) {
        final isSelected = _diasSeleccionados.contains(dia['value']);
        return FilterChip(
          label: Text(dia['label'] as String),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _diasSeleccionados.add(dia['value'] as int);
              } else {
                _diasSeleccionados.remove(dia['value']);
              }
            });
          },
          selectedColor: const Color(0xFF2563EB),
          checkmarkColor: Colors.white,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: FontWeight.w600,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDiasQuincena() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(15, (index) {
        final dia = index + 1;
        final isSelected = _diasSeleccionados.contains(dia);
        return FilterChip(
          label: Text('$dia'),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _diasSeleccionados.add(dia);
              } else {
                _diasSeleccionados.remove(dia);
              }
            });
          },
          selectedColor: const Color(0xFF2563EB),
          checkmarkColor: Colors.white,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: FontWeight.w600,
          ),
        );
      }),
    );
  }

  Widget _buildDiasMes() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(31, (index) {
        final dia = index + 1;
        final isSelected = _diasSeleccionados.contains(dia);
        return FilterChip(
          label: Text('$dia'),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _diasSeleccionados.add(dia);
              } else {
                _diasSeleccionados.remove(dia);
              }
            });
          },
          selectedColor: const Color(0xFF2563EB),
          checkmarkColor: Colors.white,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: FontWeight.w600,
          ),
        );
      }),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _isSaving ? null : _saveConfiguration,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: _isSaving
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Text(
              'Guardar Configuración',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
    );
  }

  @override
  void dispose() {
    _deudaTotalController.dispose();
    _numeroCuotasController.dispose();
    _montoCuotaController.dispose();
    super.dispose();
  }
}