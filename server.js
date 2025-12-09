const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');

// Solo cargar dotenv en desarrollo local
if (process.env.NODE_ENV !== 'production') {
  require('dotenv').config();
}

const authRoutes = require('./routes/authRoutes');

const app = express();

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

// Conexión a MongoDB
mongoose.connect(process.env.MONGODB_URI)
  .then(() => {
    console.log('✅ Conectado a MongoDB');
    app.listen(PORT, () => {
      console.log(`🚀 Servidor corriendo en puerto ${PORT}`);
    });
  })
  .catch((error) => {
    console.error('❌ Error conectando a MongoDB:', error);
    process.exit(1); // Salir si no puede conectar a la base de datos
  });