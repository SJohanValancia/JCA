// controllers/lockController.js
const DeviceLock = require('../models/DeviceLock');
const User = require('../models/User');
const DeviceLink = require('../models/DeviceLink');

// Bloquear dispositivo
exports.lockDevice = async (req, res) => {
  try {
    const duenoId = req.user.id;
    const { vendedorId, lockMessage } = req.body;

    console.log('🔒 Bloqueando dispositivo:', { duenoId, vendedorId, lockMessage });

    // Validar que el dueño tenga rol de dueño
    const dueno = await User.findById(duenoId);
    if (dueno.rol !== 'dueno') {
      return res.status(403).json({
        success: false,
        message: 'Solo los dueños pueden bloquear dispositivos'
      });
    }

    // Validar que el usuario a bloquear sea vendedor y esté vinculado
    const vendedor = await User.findById(vendedorId);
    if (!vendedor || vendedor.rol !== 'vendedor') {
      return res.status(400).json({
        success: false,
        message: 'El usuario debe ser un vendedor'
      });
    }

    // Verificar vinculación activa
    const link = await DeviceLink.findOne({
      userId: duenoId,
      linkedUserId: vendedorId,
      status: 'active'
    });

    if (!link) {
      return res.status(404).json({
        success: false,
        message: 'No existe vinculación activa con este usuario'
      });
    }

    // Crear o actualizar bloqueo
    let deviceLock = await DeviceLock.findOne({
      duenoId,
      vendedorId
    });

    if (deviceLock) {
      deviceLock.isLocked = true;
      deviceLock.lockMessage = lockMessage || 'Este dispositivo ha sido bloqueado';
      deviceLock.lockedAt = new Date();
      deviceLock.unlockedAt = null;
    } else {
      deviceLock = new DeviceLock({
        duenoId,
        vendedorId,
        isLocked: true,
        lockMessage: lockMessage || 'Este dispositivo ha sido bloqueado',
        lockedAt: new Date()
      });
    }

    await deviceLock.save();

    console.log('✅ Dispositivo bloqueado exitosamente');

    res.json({
      success: true,
      message: 'Dispositivo bloqueado exitosamente',
      lockInfo: {
        isLocked: deviceLock.isLocked,
        lockMessage: deviceLock.lockMessage,
        lockedAt: deviceLock.lockedAt
      }
    });

  } catch (error) {
    console.error('❌ Error bloqueando dispositivo:', error);
    res.status(500).json({
      success: false,
      message: 'Error en el servidor'
    });
  }
};

// Desbloquear dispositivo
exports.unlockDevice = async (req, res) => {
  try {
    const duenoId = req.user.id;
    const { vendedorId } = req.body;

    console.log('🔓 Desbloqueando dispositivo:', { duenoId, vendedorId });

    const deviceLock = await DeviceLock.findOne({
      duenoId,
      vendedorId
    });

    if (!deviceLock) {
      return res.status(404).json({
        success: false,
        message: 'No se encontró información de bloqueo'
      });
    }

    deviceLock.isLocked = false;
    deviceLock.unlockedAt = new Date();
    await deviceLock.save();

    console.log('✅ Dispositivo desbloqueado exitosamente');

    res.json({
      success: true,
      message: 'Dispositivo desbloqueado exitosamente'
    });

  } catch (error) {
    console.error('❌ Error desbloqueando dispositivo:', error);
    res.status(500).json({
      success: false,
      message: 'Error en el servidor'
    });
  }
};

// En lockController.js:
exports.checkLockStatus = async (req, res) => {
  try {
    const userId = req.user.id;
    
    // Buscar al usuario
    const user = await User.findById(userId).populate('dueno');
    
    if (!user || user.rol !== 'vendedor') {
      return res.json({ success: true, isLocked: false });
    }

    // Buscar si hay un bloqueo activo para este DISPOSITIVO
    const lockStatus = await LockStatus.findOne({
      vendedorId: userId,
      isActive: true
    });

    res.json({
      success: true,
      isLocked: lockStatus ? true : false,
      lockMessage: lockStatus?.message || null
    });
  } catch (error) {
    res.status(500).json({ success: false, isLocked: false });
  }
};
// Obtener estado de bloqueo de un vendedor específico (para el dueño)
exports.getLockStatus = async (req, res) => {
  try {
    const duenoId = req.user.id;
    const { vendedorId } = req.params;

    const deviceLock = await DeviceLock.findOne({
      duenoId,
      vendedorId
    });

    if (!deviceLock) {
      return res.json({
        success: true,
        isLocked: false
      });
    }

    res.json({
      success: true,
      isLocked: deviceLock.isLocked,
      lockMessage: deviceLock.lockMessage,
      lockedAt: deviceLock.lockedAt,
      unlockedAt: deviceLock.unlockedAt
    });

  } catch (error) {
    console.error('❌ Error obteniendo estado:', error);
    res.status(500).json({
      success: false,
      message: 'Error en el servidor'
    });
  }
};