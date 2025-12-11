// models/Link.js
const mongoose = require('mongoose');

const linkSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  linkedUserId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  status: {
    type: String,
    enum: ['pending', 'accepted', 'rejected'],
    default: 'pending'
  },
  requestedAt: {
    type: Date,
    default: Date.now
  },
  acceptedAt: {
    type: Date
  },
  // ✅ NUEVO: Configuración de deuda
  debtConfig: {
    deudaTotal: { type: Number, default: 0 },
    numeroCuotas: { type: Number, default: 0 },
    montoCuota: { type: Number, default: 0 },
    modalidadPago: { 
      type: String, 
      enum: ['diario', 'semanal', 'quincenal', 'mensual'],
      default: 'mensual'
    },
    diasPago: [{ type: Number }], // Días seleccionados según modalidad
    proximoPago: { type: Date },
    fechaInicio: { type: Date },
    cuotasPagadas: { type: Number, default: 0 }
  }
}, {
  timestamps: true
});

// Índice para búsquedas rápidas
linkSchema.index({ userId: 1, linkedUserId: 1 });
linkSchema.index({ status: 1 });

module.exports = mongoose.model('Link', linkSchema);