const mongoose = require('mongoose');

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
        // No permitir @ en el usuario
        return !v.includes('@');
      },
      message: 'El usuario no puede contener el símbolo @'
    }
  },
  password: {
    type: String,
    required: [true, 'La contraseña es obligatoria'],
    minlength: [6, 'La contraseña debe tener mínimo 6 caracteres']
  }
}, {
  timestamps: true
});

module.exports = mongoose.model('User', userSchema);