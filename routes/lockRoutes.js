// routes/lockRoutes.js
const express = require('express');
const router = express.Router();
const lockController = require('../controllers/lockController');
const authMiddleware = require('../middleware/authMiddleware');

// Todas las rutas requieren autenticación
router.use(authMiddleware);

// Rutas para el dueño
router.post('/lock', lockController.lockDevice);
router.post('/unlock', lockController.unlockDevice);
router.get('/status/:vendedorId', lockController.getLockStatus);

// Ruta para el vendedor
router.get('/check', lockController.checkLockStatus);

module.exports = router;