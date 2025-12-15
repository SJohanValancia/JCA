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
exports.respondToRequest = async (req, res) => {
  try {
    const { linkId, accept } = req.body;
    const userId = req.user.id;

    console.log('🔍 Respondiendo solicitud:', { linkId, accept, userId });

    const link = await DeviceLink.findById(linkId);
    if (!link) {
      return res.status(404).json({
        success: false,
        message: 'Solicitud no encontrada'
      });
    }

    if (link.linkedUserId.toString() !== userId.toString()) {
      console.log('❌ IDs no coinciden:', {
        linkedUserId: link.linkedUserId.toString(),
        userId: userId.toString()
      });
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
    }).populate('linkedUserId', 'nombre usuario jcId rol');

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

    // Obtener ubicaciones y poblar con isLocked
    const locations = await Location.find({
      userId: { $in: linkedUserIds }
    }).populate('userId', 'nombre usuario jcId rol isLocked'); // ✅ Agregar isLocked

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

// ============================================
// ✅ NUEVAS FUNCIONES PARA GESTIÓN DE DEUDA
// ============================================

// Configurar deuda para un vendedor vinculado
exports.configureDebt = async (req, res) => {
  try {
    const duenoId = req.user.id;
    const { linkedUserId, debtConfig } = req.body;

    console.log('📊 Configurando deuda:', { duenoId, linkedUserId, debtConfig });

    // Validar que el dueño tenga rol de dueño
    const dueno = await User.findById(duenoId);
    if (dueno.rol !== 'dueno') {
      return res.status(403).json({
        success: false,
        message: 'Solo los dueños pueden configurar deudas'
      });
    }

    // Validar que el usuario vinculado sea vendedor
    const vendedor = await User.findById(linkedUserId);
    if (!vendedor || vendedor.rol !== 'vendedor') {
      return res.status(400).json({
        success: false,
        message: 'El usuario vinculado debe ser un vendedor'
      });
    }

    // Buscar el link entre dueño y vendedor
    const link = await DeviceLink.findOne({
      userId: duenoId,
      linkedUserId: linkedUserId,
      status: 'active'
    });

    if (!link) {
      return res.status(404).json({
        success: false,
        message: 'No existe vinculación con este usuario'
      });
    }

    // Calcular próximo pago
    const proximoPago = calcularProximoPago(
      debtConfig.modalidadPago,
      debtConfig.diasPago,
      debtConfig.fechaInicio || new Date()
    );

    // Actualizar configuración de deuda en el link
    link.debtConfig = {
      deudaTotal: debtConfig.deudaTotal,
      numeroCuotas: debtConfig.numeroCuotas,
      montoCuota: debtConfig.montoCuota,
      modalidadPago: debtConfig.modalidadPago,
      diasPago: debtConfig.diasPago,
      proximoPago: proximoPago,
      fechaInicio: debtConfig.fechaInicio || new Date(),
      cuotasPagadas: 0
    };

    await link.save();

    // Actualizar deudaInfo en el perfil del vendedor
    vendedor.deudaInfo = {
      deudaTotal: debtConfig.deudaTotal,
      deudaRestante: debtConfig.deudaTotal,
      cuotasPagadas: 0,
      cuotasPendientes: debtConfig.numeroCuotas,
      montoCuota: debtConfig.montoCuota,
      proximoPago: proximoPago,
      ultimoPago: null
    };

    await vendedor.save();

    console.log('✅ Deuda configurada exitosamente');

    res.json({
      success: true,
      message: 'Configuración de deuda guardada exitosamente',
      debtConfig: link.debtConfig
    });

  } catch (error) {
    console.error('❌ Error configurando deuda:', error);
    res.status(500).json({
      success: false,
      message: 'Error en el servidor'
    });
  }
};

// Obtener configuración de deuda de un vendedor
exports.getDebtConfig = async (req, res) => {
  try {
    const duenoId = req.user.id;
    const { linkedUserId } = req.params;

    const link = await DeviceLink.findOne({
      userId: duenoId,
      linkedUserId: linkedUserId,
      status: 'active'
    });

    if (!link) {
      return res.status(404).json({
        success: false,
        message: 'No existe vinculación con este usuario'
      });
    }

    res.json({
      success: true,
      debtConfig: link.debtConfig || {}
    });

  } catch (error) {
    console.error('Error obteniendo configuración:', error);
    res.status(500).json({
      success: false,
      message: 'Error en el servidor'
    });
  }
};

// Registrar pago de cuota
exports.registerPayment = async (req, res) => {
  try {
    const duenoId = req.user.id;
    const { linkedUserId, montoPagado } = req.body;

    const link = await DeviceLink.findOne({
      userId: duenoId,
      linkedUserId: linkedUserId,
      status: 'active'
    });

    if (!link || !link.debtConfig) {
      return res.status(404).json({
        success: false,
        message: 'No hay configuración de deuda'
      });
    }

    const vendedor = await User.findById(linkedUserId);

    // Actualizar información de pago
    link.debtConfig.cuotasPagadas += 1;
    
    const nuevoProximoPago = calcularProximoPago(
      link.debtConfig.modalidadPago,
      link.debtConfig.diasPago,
      new Date()
    );
    
    link.debtConfig.proximoPago = nuevoProximoPago;
    await link.save();

    // Actualizar vendedor
    vendedor.deudaInfo.deudaRestante -= montoPagado;
    vendedor.deudaInfo.cuotasPagadas += 1;
    vendedor.deudaInfo.cuotasPendientes -= 1;
    vendedor.deudaInfo.ultimoPago = new Date();
    vendedor.deudaInfo.proximoPago = nuevoProximoPago;

    await vendedor.save();

    res.json({
      success: true,
      message: 'Pago registrado exitosamente',
      deudaInfo: vendedor.deudaInfo
    });

  } catch (error) {
    console.error('Error registrando pago:', error);
    res.status(500).json({
      success: false,
      message: 'Error en el servidor'
    });
  }
};

// Función auxiliar para calcular próximo pago
function calcularProximoPago(modalidad, diasPago, fechaInicio) {
  const ahora = new Date(fechaInicio);
  let proximoPago = new Date(ahora);

  switch (modalidad) {
    case 'diario':
      proximoPago.setDate(ahora.getDate() + 1);
      break;

    case 'semanal':
      const diaActual = ahora.getDay();
      const diasOrdenados = diasPago.sort((a, b) => a - b);
      
      let siguienteDia = diasOrdenados.find(d => d > diaActual);
      if (!siguienteDia) {
        siguienteDia = diasOrdenados[0];
        proximoPago.setDate(ahora.getDate() + (7 - diaActual + siguienteDia));
      } else {
        proximoPago.setDate(ahora.getDate() + (siguienteDia - diaActual));
      }
      break;

    case 'quincenal':
      const diaDelMes = ahora.getDate();
      if (diaDelMes <= 15) {
        proximoPago.setDate(Math.min(...diasPago.filter(d => d <= 15 && d > diaDelMes)) || 16);
      } else {
        proximoPago.setMonth(ahora.getMonth() + 1);
        proximoPago.setDate(Math.min(...diasPago.filter(d => d <= 15)) || 1);
      }
      break;

    case 'mensual':
      const diaMes = ahora.getDate();
      let siguienteDiaMes = diasPago.find(d => d > diaMes);
      
      if (!siguienteDiaMes) {
        proximoPago.setMonth(ahora.getMonth() + 1);
        proximoPago.setDate(Math.min(...diasPago));
      } else {
        proximoPago.setDate(siguienteDiaMes);
      }
      break;
  }

  return proximoPago;
}