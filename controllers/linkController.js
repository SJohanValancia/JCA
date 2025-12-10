const DeviceLink = require('../models/DeviceLink');
const User = require('../models/User');
const Location = require('../models/Location');

// Enviar solicitud de vinculación
exports.sendLinkRequest = async (req, res) => {
  try {
    const { jcId } = req.body;
    const userId = req.user.id;

    // Validar que no sea el mismo usuario
    const currentUser = await User.findById(userId);
    if (currentUser.jcId === jcId) {
      return res.status(400).json({
        success: false,
        message: 'No puedes vincularte contigo mismo'
      });
    }

    // Buscar usuario por JC-ID
    const targetUser = await User.findOne({ jcId: jcId.toUpperCase() });
    if (!targetUser) {
      return res.status(404).json({
        success: false,
        message: 'Usuario no encontrado con ese JC-ID'
      });
    }

// Eliminar solicitudes rechazadas antiguas
await DeviceLink.deleteMany({
  $or: [
    { userId, linkedUserId: targetUser._id },
    { userId: targetUser._id, linkedUserId: userId }
  ],
  status: 'rejected'
});

// Verificar si ya existe una solicitud activa o pendiente
const existingLink = await DeviceLink.findOne({
  $or: [
    { userId, linkedUserId: targetUser._id },
    { userId: targetUser._id, linkedUserId: userId }
  ],
  status: { $in: ['active', 'pending'] }
});

if (existingLink) {
  if (existingLink.status === 'active') {
    return res.status(400).json({
      success: false,
      message: 'Ya están vinculados'
    });
  } else if (existingLink.status === 'pending') {
    return res.status(400).json({
      success: false,
      message: 'Ya existe una solicitud pendiente'
    });
  }
}

    // Crear solicitud de vinculación
    const newLink = new DeviceLink({
      userId,
      linkedUserId: targetUser._id,
      status: 'pending'
    });

    await newLink.save();

    res.status(201).json({
      success: true,
      message: 'Solicitud enviada exitosamente',
      targetUser: {
        nombre: targetUser.nombre,
        jcId: targetUser.jcId
      }
    });

  } catch (error) {
    console.error('Error enviando solicitud:', error);
    res.status(500).json({
      success: false,
      message: 'Error en el servidor'
    });
  }
};

// Obtener solicitudes pendientes
exports.getPendingRequests = async (req, res) => {
  try {
    const userId = req.user.id;

    const pendingRequests = await DeviceLink.find({
      linkedUserId: userId,
      status: 'pending'
    }).populate('userId', 'nombre usuario jcId');

    res.json({
      success: true,
      requests: pendingRequests
    });

  } catch (error) {
    console.error('Error obteniendo solicitudes:', error);
    res.status(500).json({
      success: false,
      message: 'Error en el servidor'
    });
  }
};

// Responder solicitud (aceptar/rechazar)
// Responder solicitud (aceptar/rechazar)
exports.respondToRequest = async (req, res) => {
  try {
    const { linkId, accept } = req.body;
    const userId = req.user.id;

    console.log('🔔 Respondiendo solicitud:', { linkId, accept, userId });

    const link = await DeviceLink.findById(linkId);
    if (!link) {
      return res.status(404).json({
        success: false,
        message: 'Solicitud no encontrada'
      });
    }

    // Verificar que el usuario sea el destinatario
    if (link.linkedUserId.toString() !== userId) {
      return res.status(403).json({
        success: false,
        message: 'No autorizado'
      });
    }

    if (accept) {
      // ACEPTAR: Cambiar a active
      link.status = 'active';
      link.respondedAt = new Date();
      await link.save();

      // Crear vínculo bidireccional
      const reverseLink = await DeviceLink.findOne({
        userId: link.linkedUserId,
        linkedUserId: link.userId
      });

      if (!reverseLink) {
        const bidirectionalLink = new DeviceLink({
          userId: link.linkedUserId,
          linkedUserId: link.userId,
          status: 'active',
          respondedAt: new Date()
        });
        await bidirectionalLink.save();
        console.log('✅ Vínculo bidireccional creado');
      } else {
        reverseLink.status = 'active';
        reverseLink.respondedAt = new Date();
        await reverseLink.save();
        console.log('✅ Vínculo bidireccional actualizado');
      }

      console.log('✅ Solicitud aceptada');
    } else {
      // RECHAZAR: Eliminar la solicitud completamente
      await DeviceLink.deleteOne({ _id: linkId });
      console.log('❌ Solicitud eliminada');
    }

    res.json({
      success: true,
      message: accept ? 'Solicitud aceptada' : 'Solicitud rechazada'
    });

  } catch (error) {
    console.error('❌ Error respondiendo solicitud:', error);
    res.status(500).json({
      success: false,
      message: 'Error en el servidor'
    });
  }
};

// Obtener dispositivos vinculados
exports.getLinkedDevices = async (req, res) => {
  try {
    const userId = req.user.id;

    const links = await DeviceLink.find({
      userId,
      status: 'active'
    }).populate('linkedUserId', 'nombre usuario jcId');

    res.json({
      success: true,
      linkedDevices: links
    });

  } catch (error) {
    console.error('Error obteniendo dispositivos vinculados:', error);
    res.status(500).json({
      success: false,
      message: 'Error en el servidor'
    });
  }
};

// Actualizar ubicación
exports.updateLocation = async (req, res) => {
  try {
    const { latitude, longitude, address, batteryLevel, isCharging, accuracy } = req.body;
    const userId = req.user.id;

    await Location.findOneAndUpdate(
      { userId },
      {
        latitude,
        longitude,
        address,
        batteryLevel,
        isCharging,
        accuracy,
        timestamp: new Date()
      },
      { upsert: true, new: true }
    );

    res.json({
      success: true,
      message: 'Ubicación actualizada'
    });

  } catch (error) {
    console.error('Error actualizando ubicación:', error);
    res.status(500).json({
      success: false,
      message: 'Error en el servidor'
    });
  }
};

// Obtener ubicaciones de dispositivos vinculados
exports.getLinkedLocations = async (req, res) => {
  try {
    const userId = req.user.id;

    // Obtener usuarios vinculados
    const links = await DeviceLink.find({
      userId,
      status: 'active'
    }).select('linkedUserId');

    const linkedUserIds = links.map(link => link.linkedUserId);

    // Obtener ubicaciones
    const locations = await Location.find({
      userId: { $in: linkedUserIds }
    }).populate('userId', 'nombre usuario jcId');

    res.json({
      success: true,
      locations
    });

  } catch (error) {
    console.error('Error obteniendo ubicaciones:', error);
    res.status(500).json({
      success: false,
      message: 'Error en el servidor'
    });
  }
};

// Desvincular dispositivo
exports.unlinkDevice = async (req, res) => {
  try {
    const { linkedUserId } = req.body;
    const userId = req.user.id;

    // Eliminar ambos vínculos
    await DeviceLink.deleteMany({
      $or: [
        { userId, linkedUserId },
        { userId: linkedUserId, linkedUserId: userId }
      ]
    });

    res.json({
      success: true,
      message: 'Dispositivo desvinculado'
    });

  } catch (error) {
    console.error('Error desvinculando:', error);
    res.status(500).json({
      success: false,
      message: 'Error en el servidor'
    });
  }
};