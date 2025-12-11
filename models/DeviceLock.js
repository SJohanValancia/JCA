// models/DeviceLock.js
const mongoose = require('mongoose');

const deviceLockSchema = new mongoose.Schema({
  duenoId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  vendedorId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  isLocked: {
    type: Boolean,
    default: false
  },
  lockMessage: {
    type: String,
    default: 'Este dispositivo ha sido bloqueado'
  },
  lockedAt: {
    type: Date
  },
  unlockedAt: {
    type: Date
  }
}, {
  timestamps: true
});

// Índice para búsquedas rápidas
deviceLockSchema.index({ vendedorId: 1 });
deviceLockSchema.index({ duenoId: 1, vendedorId: 1 });

module.exports = mongoose.model('DeviceLock', deviceLockSchema);