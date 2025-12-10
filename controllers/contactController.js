const EmergencyContact = require('../models/EmergencyContact');

// Marcar/actualizar contacto como emergencia
exports.toggleEmergencyContact = async (req, res) => {
  try {
    const { name, phoneNumber, isEmergency } = req.body;
    const userId = req.user.id;

    console.log('📞 Toggle contacto:', { name, phoneNumber, isEmergency, userId });

    if (!name || !phoneNumber) {
      return res.status(400).json({
        success: false,
        message: 'Nombre y número de teléfono son obligatorios'
      });
    }

    const cleanPhone = phoneNumber.replace(/\D/g, '');

    if (isEmergency) {
      // Crear o actualizar contacto de emergencia
      const contact = await EmergencyContact.findOneAndUpdate(
        { userId, phoneNumber: cleanPhone },
        {
          name,
          phoneNumber: cleanPhone,
          isEmergency: true
        },
        { upsert: true, new: true }
      );

      console.log('✅ Contacto marcado como emergencia:', contact);

      return res.status(201).json({
        success: true,
        message: 'Contacto marcado como emergencia',
        contact
      });
    } else {
      // Eliminar contacto de emergencias
      const result = await EmergencyContact.deleteOne({ userId, phoneNumber: cleanPhone });
      
      console.log('🗑️ Contacto eliminado:', result);

      return res.json({
        success: true,
        message: 'Contacto eliminado de emergencias'
      });
    }

  } catch (error) {
    console.error('❌ Error en toggleEmergencyContact:', error);
    
    if (error.code === 11000) {
      return res.status(400).json({
        success: false,
        message: 'Este contacto ya está marcado como emergencia'
      });
    }

    res.status(500).json({
      success: false,
      message: 'Error en el servidor'
    });
  }
};

// Obtener todos los contactos de emergencia del usuario
exports.getEmergencyContacts = async (req, res) => {
  try {
    const userId = req.user.id;

    const contacts = await EmergencyContact.find({ 
      userId, 
      isEmergency: true 
    }).sort({ createdAt: -1 });

    console.log(`📋 Contactos de emergencia encontrados: ${contacts.length}`);

    res.json({
      success: true,
      emergencyContacts: contacts
    });

  } catch (error) {
    console.error('❌ Error obteniendo contactos:', error);
    res.status(500).json({
      success: false,
      message: 'Error en el servidor'
    });
  }
};

// Eliminar contacto de emergencia
exports.removeEmergencyContact = async (req, res) => {
  try {
    const { contactId } = req.params;
    const userId = req.user.id;

    const contact = await EmergencyContact.findOne({ 
      _id: contactId, 
      userId 
    });

    if (!contact) {
      return res.status(404).json({
        success: false,
        message: 'Contacto no encontrado'
      });
    }

    await EmergencyContact.deleteOne({ _id: contactId, userId });

    res.json({
      success: true,
      message: 'Contacto eliminado de emergencias'
    });

  } catch (error) {
    console.error('Error eliminando contacto:', error);
    res.status(500).json({
      success: false,
      message: 'Error en el servidor'
    });
  }
};

// Obtener cantidad de contactos de emergencia
exports.getEmergencyContactsCount = async (req, res) => {
  try {
    const userId = req.user.id;

    const count = await EmergencyContact.countDocuments({ 
      userId, 
      isEmergency: true 
    });

    res.json({
      success: true,
      count
    });

  } catch (error) {
    console.error('Error contando contactos:', error);
    res.status(500).json({
      success: false,
      message: 'Error en el servidor'
    });
  }
};

// Buscar contacto de emergencia por número
exports.findEmergencyContactByPhone = async (req, res) => {
  try {
    const { phoneNumber } = req.params;
    const userId = req.user.id;

    const cleanPhone = phoneNumber.replace(/\D/g, '');

    const contact = await EmergencyContact.findOne({ 
      userId, 
      phoneNumber: cleanPhone,
      isEmergency: true 
    });

    if (!contact) {
      return res.status(404).json({
        success: false,
        message: 'Contacto no encontrado'
      });
    }

    res.json({
      success: true,
      contact
    });

  } catch (error) {
    console.error('Error buscando contacto:', error);
    res.status(500).json({
      success: false,
      message: 'Error en el servidor'
    });
  }
};