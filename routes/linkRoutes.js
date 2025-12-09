const express = require('express');
const router = express.Router();
const linkController = require('../controllers/linkController');
const authMiddleware = require('../middleware/authMiddleware');

// Todas las rutas requieren autenticación
router.use(authMiddleware);

// Vinculación de dispositivos
router.post('/request', linkController.sendLinkRequest);
router.get('/pending', linkController.getPendingRequests);
router.post('/respond', linkController.respondToRequest);
router.get('/devices', linkController.getLinkedDevices);
router.post('/unlink', linkController.unlinkDevice);

// Ubicaciones
router.post('/location/update', linkController.updateLocation);
router.get('/location/linked', linkController.getLinkedLocations);

module.exports = router;