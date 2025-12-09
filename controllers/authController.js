const User = require('../models/User');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

// Registro de usuario
exports.registro = async (req, res) => {
  try {
    const { nombre, telefono, usuario, password } = req.body;

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
      password: passwordHash
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
        jcId: nuevoUsuario.jcId // 🆕 Incluir JC-ID
      }
    });

  } catch (error) {
    console.error('Error en registro:', error);
    res.status(500).json({ 
      success: false,
      message: 'Error en el servidor' 
    });
  }
};

// Login de usuario
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

    // ✅ AGREGA ESTAS LÍNEAS AQUÍ
    console.log('===== USUARIO ENCONTRADO =====');
    console.log('ID:', usuarioEncontrado._id);
    console.log('Nombre:', usuarioEncontrado.nombre);
    console.log('JC-ID:', usuarioEncontrado.jcId);
    console.log('============================');

    res.json({
      success: true,
      message: 'Login exitoso',
      token,
      usuario: {
        id: usuarioEncontrado._id,
        nombre: usuarioEncontrado.nombre,
        telefono: usuarioEncontrado.telefono,
        usuario: usuarioEncontrado.usuario,
        jcId: usuarioEncontrado.jcId
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