// authController.js
const User = require('../models/User');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');


// ✅ NUEVA FUNCIÓN: Verificar pagos del vendedor actual
exports.checkMyPayments = async (req, res) => {
  try {
    const userId = req.user.id;
    const user = await User.findById(userId);

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Usuario no encontrado'
      });
    }

    console.log(`💰 Verificando pagos para: ${user.nombre}`);

    // Si no es vendedor o no tiene deuda
    if (user.rol !== 'vendedor' || !user.deudaInfo || user.deudaInfo.deudaRestante <= 0) {
      return res.json({
        success: true,
        hasDebt: false,
        message: 'No tienes deuda pendiente'
      });
    }

    const now = new Date();
    now.setHours(0, 0, 0, 0);
    
    const proximoPago = new Date(user.deudaInfo.proximoPago);
    proximoPago.setHours(0, 0, 0, 0);

    const diffTime = proximoPago - now;
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

    let notificationType = null;
    if (diffDays === 2) notificationType = '2days';
    else if (diffDays === 1) notificationType = '1day';
    else if (diffDays === 0) notificationType = 'today';

    console.log(`📊 ${user.nombre}: Faltan ${diffDays} días para el pago`);
    console.log(`🔔 Tipo de notificación: ${notificationType || 'ninguna'}`);

    res.json({
      success: true,
      hasDebt: true,
      deudaInfo: user.deudaInfo,
      daysUntilPayment: diffDays,
      notificationType,
      shouldNotify: notificationType !== null
    });

  } catch (error) {
    console.error('❌ Error verificando pagos:', error);
    res.status(500).json({
      success: false,
      message: 'Error en el servidor'
    });
  }
};

// Registro de usuario
exports.registro = async (req, res) => {
  try {
    const { nombre, telefono, usuario, password, rol } = req.body;

    if (!nombre || !telefono || !usuario || !password) {
      return res.status(400).json({ 
        success: false,
        message: 'Todos los campos son obligatorios' 
      });
    }

    if (password.length < 6) {
      return res.status(400).json({ 
        success: false,
        message: 'La contraseña debe tener mínimo 6 caracteres' 
      });
    }

    if (usuario.includes('@')) {
      return res.status(400).json({ 
        success: false,
        message: 'El usuario no puede contener el símbolo @' 
      });
    }

    // ✅ Validar rol
    if (rol && !['dueno', 'vendedor'].includes(rol)) {
      return res.status(400).json({ 
        success: false,
        message: 'Rol inválido' 
      });
    }

    const usuarioExiste = await User.findOne({ usuario: usuario.toLowerCase() });
    if (usuarioExiste) {
      return res.status(400).json({ 
        success: false,
        message: 'El usuario ya está registrado' 
      });
    }

    const telefonoExiste = await User.findOne({ telefono });
    if (telefonoExiste) {
      return res.status(400).json({ 
        success: false,
        message: 'El número de teléfono ya está registrado' 
      });
    }

    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(password, salt);

    const nuevoUsuario = new User({
      nombre,
      telefono,
      usuario: usuario.toLowerCase(),
      password: passwordHash,
      rol: rol || 'dueno'
    });

    await nuevoUsuario.save();

    const token = jwt.sign(
      { id: nuevoUsuario._id },
      process.env.JWT_SECRET,
      { expiresIn: '30d' }
    );

    res.status(201).json({
      success: true,
      message: 'Usuario registrado exitosamente',
      token,
      usuario: {
        id: nuevoUsuario._id,
        nombre: nuevoUsuario.nombre,
        telefono: nuevoUsuario.telefono,
        usuario: nuevoUsuario.usuario,
        jcId: nuevoUsuario.jcId,
        rol: nuevoUsuario.rol,
        deudaInfo: nuevoUsuario.deudaInfo
      }
    });

} catch (error) {
  console.error('===== ERROR COMPLETO EN REGISTRO =====');
  console.error('Error:', error);
  console.error('Mensaje:', error.message);
  console.error('Stack:', error.stack);
  console.error('====================================');
  res.status(500).json({ 
    success: false,
    message: 'Error en el servidor',
    error: error.message
  });
}
};

// En authController.js, agregar:
exports.registrarDispositivo = async (req, res) => {
  try {
    const { deviceId, deviceInfo } = req.body;
    const userId = req.user.id;

    const user = await User.findByIdAndUpdate(
      userId,
      { 
        deviceId,
        deviceInfo: {
          ...deviceInfo,
          registradoEn: new Date()
        }
      },
      { new: true }
    );

    res.json({
      success: true,
      message: 'Dispositivo registrado'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// Login de usuario
exports.login = async (req, res) => {
  try {
    const { usuario, password } = req.body;

    if (!usuario || !password) {
      return res.status(400).json({ 
        success: false,
        message: 'Usuario y contraseña son obligatorios' 
      });
    }

    const usuarioEncontrado = await User.findOne({ usuario: usuario.toLowerCase() });
    if (!usuarioEncontrado) {
      return res.status(401).json({ 
        success: false,
        message: 'Usuario o contraseña incorrectos' 
      });
    }

    const passwordValido = await bcrypt.compare(password, usuarioEncontrado.password);
    if (!passwordValido) {
      return res.status(401).json({ 
        success: false,
        message: 'Usuario o contraseña incorrectos' 
      });
    }

    const token = jwt.sign(
      { id: usuarioEncontrado._id },
      process.env.JWT_SECRET,
      { expiresIn: '30d' }
    );

    console.log('===== USUARIO ENCONTRADO =====');
    console.log('ID:', usuarioEncontrado._id);
    console.log('Nombre:', usuarioEncontrado.nombre);
    console.log('JC-ID:', usuarioEncontrado.jcId);
    console.log('Rol:', usuarioEncontrado.rol);
    console.log('============================');

    // ✅ AGREGAR ESTOS LOGS:
    console.log('===== DEUDA INFO COMPLETA =====');
    console.log('deudaInfo completo:', JSON.stringify(usuarioEncontrado.deudaInfo, null, 2));
    console.log('deudaTotal:', usuarioEncontrado.deudaInfo?.deudaTotal);
    console.log('deudaRestante:', usuarioEncontrado.deudaInfo?.deudaRestante);
    console.log('cuotasPagadas:', usuarioEncontrado.deudaInfo?.cuotasPagadas);
    console.log('cuotasPendientes:', usuarioEncontrado.deudaInfo?.cuotasPendientes);
    console.log('montoCuota:', usuarioEncontrado.deudaInfo?.montoCuota);
    console.log('================================');

    res.json({
      success: true,
      message: 'Login exitoso',
      token,
      usuario: {
        id: usuarioEncontrado._id,
        nombre: usuarioEncontrado.nombre,
        telefono: usuarioEncontrado.telefono,
        usuario: usuarioEncontrado.usuario,
        jcId: usuarioEncontrado.jcId,
        rol: usuarioEncontrado.rol,
        deudaInfo: usuarioEncontrado.deudaInfo
      }
    });

  } catch (error) {
    console.error('Error en login:', error);
    res.status(500).json({ 
      success: false,
      message: 'Error en el servidor' 
    });
  }
};