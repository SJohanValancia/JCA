const express = require('express');
const router = express.Router();
const contactController = require('../controllers/contactController');
const authMiddleware = require('../middleware/authMiddleware');

// Todas las rutas requieren autenticación
router.use(authMiddleware);

// Rutas de contactos de emergencia
router.post('/emergency', contactController.toggleEmergencyContact);
router.get('/emergency', contactController.getEmergencyContacts);
router.delete('/emergency/:contactId', contactController.removeEmergencyContact);
router.get('/emergency/count', contactController.getEmergencyContactsCount);
router.get('/emergency/phone/:phoneNumber', contactController.findEmergencyContactByPhone);

module.exports = router;