const express = require('express');
const router = express.Router();
const paymentController = require('../controllers/paymentController');
const authMiddleware = require('../middleware/authMiddleware');

router.post('/registrar-abono', authMiddleware, paymentController.registrarAbono);

module.exports = router;