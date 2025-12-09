const mongoose = require('mongoose');

const deviceLinkSchema = new mongoose.Schema({
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
    enum: ['pending', 'active', 'rejected'],
    default: 'pending'
  },
  requestedAt: {
    type: Date,
    default: Date.now
  },
  respondedAt: {
    type: Date
  }
}, {
  timestamps: true
});

// Índice para búsquedas rápidas
deviceLinkSchema.index({ userId: 1, linkedUserId: 1 }, { unique: true });

module.exports = mongoose.model('DeviceLink', deviceLinkSchema);