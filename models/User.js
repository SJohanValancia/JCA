// User.js
const mongoose = require('mongoose');
const crypto = require('crypto');

const userSchema = new mongoose.Schema({
  nombre: {
    type: String,
    required: [true, 'El nombre es obligatorio'],
    trim: true
  },
  telefono: {
    type: String,
    required: [true, 'El teléfono es obligatorio'],
    unique: true,
    trim: true
  },
  usuario: {
    type: String,
    required: [true, 'El usuario es obligatorio'],
    unique: true,
    trim: true,
    lowercase: true,
    validate: {
      validator: function(v) {
        return !v.includes('@');
      },
      message: 'El usuario no puede contener el símbolo @'
    }
  },
  password: {
    type: String,
    required: [true, 'La contraseña es obligatoria'],
    minlength: [6, 'La contraseña debe tener mínimo 6 caracteres']
  },
  jcId: {
    type: String,
    unique: true,
  },
  // ✅ NUEVO: Rol del usuario
  rol: {
    type: String,
    enum: ['dueno', 'vendedor'],
    default: 'dueno',
    required: true
  },
  // ✅ NUEVO: Información de deuda para vendedores
  deudaInfo: {
    deudaTotal: { type: Number, default: 0 },
    deudaRestante: { type: Number, default: 0 },
    cuotasPagadas: { type: Number, default: 0 },
    cuotasPendientes: { type: Number, default: 0 },
    montoCuota: { type: Number, default: 0 },
    proximoPago: { type: Date },
    ultimoPago: { type: Date }
  }
}, {
  timestamps: true
});

// Generar JC-ID único antes de guardar
userSchema.pre('save', async function() {
  if (!this.jcId) {
    let isUnique = false;
    let jcId;
    
    while (!isUnique) {
      // Generar ID aleatorio de 8 caracteres
      const randomBytes = crypto.randomBytes(4);
      jcId = 'JC' + randomBytes.toString('hex').toUpperCase();
      
      // Verificar si ya existe
      const existing = await mongoose.models.User.findOne({ jcId });
      if (!existing) {
        isUnique = true;
      }
    }
    
    this.jcId = jcId;
  }
});

module.exports = mongoose.model('User', userSchema);