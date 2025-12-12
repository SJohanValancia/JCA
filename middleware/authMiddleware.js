const jwt = require('jsonwebtoken');
const User = require('../models/User');

module.exports = async (req, res, next) => {
  try {
    // Obtener token del header
    const token = req.header('Authorization')?.replace('Bearer ', '');

    if (!token) {
      return res.status(401).json({
        success: false,
        message: 'Acceso denegado. No hay token.'
      });
    }

    // Verificar token
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    // ✅ LOG para debug
    console.log('🔐 Token decodificado:', {
      userId: decoded.id,
      timestamp: new Date().toISOString()
    });
    
    const user = await User.findById(decoded.id);

    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Token inválido'
      });
    }

    req.user = { id: user._id };
    next();

  } catch (error) {
    console.error('❌ Error en authMiddleware:', error.message);
    res.status(401).json({
      success: false,
      message: 'Token inválido'
    });
  }
};