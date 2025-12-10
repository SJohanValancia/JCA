const mongoose = require('mongoose');

const emergencyContactSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  name: {
    type: String,
    required: true,
    trim: true
  },
  phoneNumber: {
    type: String,
    required: true,
    trim: true
  },
  isEmergency: {
    type: Boolean,
    default: true
  }
}, {
  timestamps: true
});

// Índice compuesto para evitar duplicados por usuario y teléfono
emergencyContactSchema.index({ userId: 1, phoneNumber: 1 }, { unique: true });

module.exports = mongoose.model('EmergencyContact', emergencyContactSchema);