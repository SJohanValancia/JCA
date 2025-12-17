const User = require('../models/User');

// ✅ Verificar vendedores con pagos próximos
async function checkAndSendPaymentNotifications() {
  try {
    console.log('🔔 ========================================');
    console.log('🔔 Verificando pagos pendientes...');
    console.log('📅 Fecha:', new Date().toLocaleString('es-CO'));

    const now = new Date();
    now.setHours(0, 0, 0, 0);

    // Buscar vendedores con deuda pendiente
    const vendedores = await User.find({
      rol: 'vendedor',
      'deudaInfo.deudaRestante': { $gt: 0 },
      'deudaInfo.proximoPago': { $exists: true, $ne: null }
    });

    console.log(`📋 Vendedores con deuda: ${vendedores.length}`);

    const result = {
      total: vendedores.length,
      con2dias: [],
      con1dia: [],
      hoy: []
    };

    for (const vendedor of vendedores) {
      const proximoPago = new Date(vendedor.deudaInfo.proximoPago);
      proximoPago.setHours(0, 0, 0, 0);

      const diffTime = proximoPago - now;
      const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

      console.log(`👤 ${vendedor.nombre} (${vendedor.jcId}): Faltan ${diffDays} días`);

      if (diffDays === 2) {
        result.con2dias.push({
          id: vendedor._id,
          nombre: vendedor.nombre,
          jcId: vendedor.jcId
        });
      } else if (diffDays === 1) {
        result.con1dia.push({
          id: vendedor._id,
          nombre: vendedor.nombre,
          jcId: vendedor.jcId
        });
      } else if (diffDays === 0) {
        result.hoy.push({
          id: vendedor._id,
          nombre: vendedor.nombre,
          jcId: vendedor.jcId
        });
      }
    }

    console.log('📊 Resumen:');
    console.log(`   - Pago en 2 días: ${result.con2dias.length}`);
    console.log(`   - Pago en 1 día: ${result.con1dia.length}`);
    console.log(`   - Pago hoy: ${result.hoy.length}`);
    console.log('✅ Verificación completada');
    console.log('🔔 ========================================');

    return result;
  } catch (error) {
    console.error('❌ Error verificando pagos:', error);
    return null;
  }
}

module.exports = {
  checkAndSendPaymentNotifications
};