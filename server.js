const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');

// Solo cargar dotenv en desarrollo local
if (process.env.NODE_ENV !== 'production') {
  require('dotenv').config();
}

const authRoutes = require('./routes/authRoutes');

const app = express();

// DIAGNÓSTICO: Imprimir variables de entorno
console.log('🔍 NODE_ENV:', process.env.NODE_ENV);
console.log('🔍 PORT:', process.env.PORT);
console.log('🔍 MONGODB_URI existe:', !!process.env.MONGODB_URI);
console.log('🔍 JWT_SECRET existe:', !!process.env.JWT_SECRET);

// Middlewares
app.use(cors());
app.use(express.json());

// Rutas
app.use('/api/auth', authRoutes);

// Ruta de prueba
app.get('/', (req, res) => {
  res.json({ message: 'Security App API funcionando correctamente' });
});

// Puerto (Render asigna automáticamente el puerto)
const PORT = process.env.PORT || 5000;
const MONGODB_URI = process.env.MONGODB_URI;

// Validar que exista la URI antes de conectar
if (!MONGODB_URI) {
  console.error('❌ MONGODB_URI no está definida en las variables de entorno');
  process.exit(1);
}

// Conexión a MongoDB
mongoose.connect(MONGODB_URI)
  .then(() => {
    console.log('✅ Conectado a MongoDB');
    app.listen(PORT, () => {
      console.log(`🚀 Servidor corriendo en puerto ${PORT}`);
    });
  })
  .catch((error) => {
    console.error('❌ Error conectando a MongoDB:', error);
    process.exit(1);
  });