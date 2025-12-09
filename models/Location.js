const mongoose = require('mongoose');

const locationSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    unique: true
  },
  latitude: {
    type: Number,
    required: true
  },
  longitude: {
    type: Number,
    required: true
  },
  address: {
    type: String
  },
  batteryLevel: {
    type: Number,
    min: 0,
    max: 100
  },
  isCharging: {
    type: Boolean,
    default: false
  },
  accuracy: {
    type: Number
  },
  timestamp: {
    type: Date,
    default: Date.now
  }
}, {
  timestamps: true
});

// Índice para expirar ubicaciones antiguas (opcional)
locationSchema.index({ timestamp: 1 }, { expireAfterSeconds: 86400 }); // 24 horas

module.exports = mongoose.model('Location', locationSchema);