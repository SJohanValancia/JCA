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
    required: true
  }
}, {
  timestamps: true
});

// Generar JC-ID único antes de guardar
userSchema.pre('save', async function(next) {
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
  next();
});

module.exports = mongoose.model('User', userSchema);