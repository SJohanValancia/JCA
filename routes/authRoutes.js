const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const authMiddleware = require('../middleware/authMiddleware'); // ✅ Importar middleware

router.post('/registro', authController.registro);
router.post('/login', authController.login);
router.post('/registrar-dispositivo', authMiddleware, authController.registrarDispositivo); // ✅ NUEVA RUTA
router.get('/check-my-payments', authMiddleware, authController.checkMyPayments);


module.exports = router;