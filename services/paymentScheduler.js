const cron = require('node-cron');
const { checkAndSendPaymentNotifications } = require('./notificationService');

// ✅ Programar verificación diaria a las 8:00 AM
function startPaymentScheduler() {
  console.log('🕐 ========================================');
  console.log('🕐 Iniciando scheduler de notificaciones de pago...');
  console.log('⏰ Programado para ejecutarse cada día a las 8:00 AM (hora de Colombia)');
  console.log('🕐 ========================================');
  
  // Ejecutar cada día a las 8:00 AM
  // Formato: segundo minuto hora día mes día-semana
  cron.schedule('0 8 * * *', async () => {
    console.log('\n⏰ ===== EJECUTANDO VERIFICACIÓN PROGRAMADA =====');
    console.log('📅 Fecha y hora:', new Date().toLocaleString('es-CO'));
    
    try {
      await checkAndSendPaymentNotifications();
      console.log('✅ Verificación programada completada exitosamente');
    } catch (error) {
      console.error('❌ Error en verificación programada:', error);
    }
    
    console.log('⏰ ===== FIN DE VERIFICACIÓN PROGRAMADA =====\n');
  }, {
    timezone: "America/Bogota"
  });

  console.log('✅ Scheduler activo - Próxima ejecución: mañana 8:00 AM');
}

// ✅ Ejecutar verificación manual (para pruebas)
async function runManualCheck() {
  console.log('\n🔧 ===== EJECUTANDO VERIFICACIÓN MANUAL =====');
  console.log('📅 Fecha y hora:', new Date().toLocaleString('es-CO'));
  
  try {
    await checkAndSendPaymentNotifications();
    console.log('✅ Verificación manual completada');
  } catch (error) {
    console.error('❌ Error en verificación manual:', error);
  }
  
  console.log('🔧 ===== FIN DE VERIFICACIÓN MANUAL =====\n');
}

module.exports = {
  startPaymentScheduler,
  runManualCheck
};