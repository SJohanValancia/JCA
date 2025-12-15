const User = require('../models/User');

exports.registrarAbono = async (req, res) => {
  try {
    const duenoId = req.user.id; // El dueño que hace el abono
    const { vendedorId, montoAbono } = req.body;

    if (!vendedorId || !montoAbono) {
      return res.status(400).json({
        success: false,
        message: 'Vendedor y monto son obligatorios'
      });
    }

    if (montoAbono <= 0) {
      return res.status(400).json({
        success: false,
        message: 'El monto debe ser mayor a 0'
      });
    }

    // Buscar al vendedor
    const vendedor = await User.findById(vendedorId);
    if (!vendedor) {
      return res.status(404).json({
        success: false,
        message: 'Vendedor no encontrado'
      });
    }

    // Verificar que sea vendedor
    if (vendedor.rol !== 'vendedor') {
      return res.status(400).json({
        success: false,
        message: 'El usuario no es un vendedor'
      });
    }

    const deudaInfo = vendedor.deudaInfo;

    // Verificar que tenga deuda
    if (!deudaInfo || deudaInfo.deudaRestante <= 0) {
      return res.status(400).json({
        success: false,
        message: 'Este vendedor no tiene deuda pendiente'
      });
    }

    // Verificar que el abono no sea mayor a la deuda restante
    if (montoAbono > deudaInfo.deudaRestante) {
      return res.status(400).json({
        success: false,
        message: `El abono no puede ser mayor a la deuda restante ($${deudaInfo.deudaRestante})`
      });
    }

    // Calcular nueva deuda restante
    const nuevaDeudaRestante = deudaInfo.deudaRestante - montoAbono;

    // Calcular cuotas pagadas
    const cuotasPagadas = Math.floor((deudaInfo.deudaTotal - nuevaDeudaRestante) / deudaInfo.montoCuota);
    const cuotasPendientes = Math.ceil(nuevaDeudaRestante / deudaInfo.montoCuota);

    // Actualizar información de deuda
    vendedor.deudaInfo = {
      ...deudaInfo,
      deudaRestante: nuevaDeudaRestante,
      cuotasPagadas,
      cuotasPendientes,
      ultimoPago: new Date(),
    };

    await vendedor.save();

    console.log('✅ Abono registrado exitosamente');
    console.log(`   Vendedor: ${vendedor.nombre}`);
    console.log(`   Monto: $${montoAbono}`);
    console.log(`   Nueva deuda: $${nuevaDeudaRestante}`);
    console.log(`   Cuotas pagadas: ${cuotasPagadas}`);

    res.json({
      success: true,
      message: 'Abono registrado exitosamente',
      deudaActualizada: {
        deudaTotal: vendedor.deudaInfo.deudaTotal,
        deudaRestante: nuevaDeudaRestante,
        cuotasPagadas,
        cuotasPendientes,
        montoCuota: vendedor.deudaInfo.montoCuota,
        ultimoPago: vendedor.deudaInfo.ultimoPago,
      }
    });

  } catch (error) {
    console.error('❌ Error registrando abono:', error);
    res.status(500).json({
      success: false,
      message: 'Error en el servidor'
    });
  }
};