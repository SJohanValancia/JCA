import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../services/contact_service.dart';
import '../models/emergency_contact_model.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final _contactService = ContactService();
  final _searchController = TextEditingController();
  
  List<Contact> _allContacts = [];
  List<Contact> _filteredContacts = [];
  List<EmergencyContact> _emergencyContacts = [];
  bool _isLoading = true;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => _isLoading = true);
    
    final hasPermission = await _contactService.requestContactsPermission();
    
    if (hasPermission) {
      final contacts = await _contactService.getDeviceContacts();
      final emergencyContacts = await _contactService.getEmergencyContacts();
      
      if (mounted) {
        setState(() {
          _hasPermission = true;
          _allContacts = contacts;
          _filteredContacts = contacts;
          _emergencyContacts = emergencyContacts;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _hasPermission = false;
          _isLoading = false;
        });
      }
    }
  }

  void _filterContacts(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredContacts = _allContacts;
      });
      return;
    }

    final filtered = _allContacts.where((contact) {
      final name = contact.displayName.toLowerCase();
      final phones = contact.phones.map((p) => p.number).join(' ');
      final searchLower = query.toLowerCase();
      
      return name.contains(searchLower) || phones.contains(searchLower);
    }).toList();

    setState(() {
      _filteredContacts = filtered;
    });
  }

  bool _isEmergencyContact(Contact contact) {
    final phone = contact.phones.isNotEmpty
        ? contact.phones.first.number.replaceAll(RegExp(r'\D'), '')
        : '';
    
    return _emergencyContacts.any((ec) => 
      ec.phoneNumber.replaceAll(RegExp(r'\D'), '') == phone
    );
  }

  Future<void> _toggleEmergency(Contact contact) async {
    final name = contact.displayName.isNotEmpty 
        ? contact.displayName 
        : 'Sin nombre';
    
    final phone = contact.phones.isNotEmpty 
        ? contact.phones.first.number
        : '';

    if (phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Este contacto no tiene número de teléfono'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final isCurrentlyEmergency = _isEmergencyContact(contact);
    
    print('🎯 Toggling: $name - isCurrently: $isCurrentlyEmergency -> ${!isCurrentlyEmergency}');
    
    final success = await _contactService.toggleEmergencyContact(
      name: name,
      phoneNumber: phone,
      isEmergency: !isCurrentlyEmergency,
    );

    if (success && mounted) {
      // Recargar lista
      await _initialize();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isCurrentlyEmergency 
                ? '✓ Contacto eliminado de emergencias'
                : '✓ Contacto marcado como emergencia',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Error al actualizar contacto'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contactos de Emergencia'),
        backgroundColor: const Color(0xFFEF4444),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFEF4444)),
            )
          : !_hasPermission
              ? _buildNoPermissionView()
              : _buildContactsList(),
    );
  }

  Widget _buildNoPermissionView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.contacts_outlined,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 24),
            const Text(
              'Permiso de Contactos Requerido',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Necesitamos acceso a tus contactos para marcar contactos de emergencia',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _initialize,
              icon: const Icon(Icons.refresh),
              label: const Text('Solicitar Permiso'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactsList() {
    // Separar contactos de emergencia y normales
    final emergencyList = _filteredContacts.where((c) => _isEmergencyContact(c)).toList();
    final normalList = _filteredContacts.where((c) => !_isEmergencyContact(c)).toList();

    return Column(
      children: [
        // Buscador
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            onChanged: _filterContacts,
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o número',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _filterContacts('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // Lista de contactos
        Expanded(
          child: _filteredContacts.isEmpty
              ? const Center(
                  child: Text(
                    'No se encontraron contactos',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView(
                  children: [
                    // Contactos de emergencia
                    if (emergencyList.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Text(
                          'CONTACTOS DE EMERGENCIA',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      ...emergencyList.map((contact) => _buildContactCard(contact, true)),
                      const SizedBox(height: 16),
                    ],

                    // Contactos normales
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text(
                        'TODOS LOS CONTACTOS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    ...normalList.map((contact) => _buildContactCard(contact, false)),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildContactCard(Contact contact, bool isEmergency) {
    final name = contact.displayName.isNotEmpty 
        ? contact.displayName 
        : 'Sin nombre';
    
    final phone = contact.phones.isNotEmpty 
        ? contact.phones.first.number
        : 'Sin número';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isEmergency ? const Color(0xFFFFEBEE) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEmergency ? const Color(0xFFEF4444) : Colors.grey[200]!,
          width: isEmergency ? 2 : 1,
        ),
        boxShadow: isEmergency 
            ? [
                BoxShadow(
                  color: const Color(0xFFEF4444).withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isEmergency 
              ? const Color(0xFFEF4444) 
              : const Color(0xFF2563EB),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (isEmergency)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'EMERGENCIA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          phone,
          style: const TextStyle(fontSize: 13),
        ),
        trailing: IconButton(
          onPressed: () => _toggleEmergency(contact),
          icon: Icon(
            isEmergency ? Icons.star : Icons.star_border,
            color: isEmergency ? const Color(0xFFEF4444) : Colors.grey,
            size: 28,
          ),
          tooltip: isEmergency ? 'Quitar de emergencias' : 'Marcar como emergencia',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}