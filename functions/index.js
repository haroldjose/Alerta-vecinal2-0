const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getMessaging } = require('firebase-admin/messaging');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

// Inicializar Firebase Admin
initializeApp();

// Función que se ejecuta cuando se crea un documento en 'notifications'
exports.sendReportNotification = onDocumentCreated(
  'notifications/{notificationId}',
  async (event) => {
    const snapshot = event.data;
    
    if (!snapshot) {
      console.log(' No hay datos en el snapshot');
      return null;
    }

    const notification = snapshot.data();
    
    // Solo procesar notificaciones pendientes
    if (notification.status !== 'pending') {
      console.log(' Notificación ya procesada, saltando...');
      return null;
    }

    const { tokens, title, body, reportId, reportType } = notification;

    // Validar que hay tokens
    if (!tokens || tokens.length === 0) {
      console.log(' No hay tokens para enviar notificaciones');
      await snapshot.ref.update({
        status: 'skipped',
        reason: 'No tokens available',
      });
      return null;
    }

    console.log(`📤 Enviando notificación [${reportType ?? 'sin categoría'}] a ${tokens.length} dispositivo(s)...`);


    try {
      const messaging = getMessaging();
      
      // Enviar notificación a múltiples dispositivos
      const response = await messaging.sendEachForMulticast({
        tokens: tokens,
        notification: {
          title: title,
          body: body,
        },
        data: {
          reportId: reportId || '',
          reportType: reportType || '',
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'reports_channel',
            sound: 'default',
            color: '#D63031',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      });

      console.log(` Notificaciones enviadas: ${response.successCount}/${tokens.length}`);
      
      // Log de errores si los hay
      if (response.failureCount > 0) {
        console.log(` Notificaciones fallidas: ${response.failureCount}`);
        
        const failedTokens = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            console.error(`Token ${tokens[idx]} falló:`, resp.error);
            failedTokens.push(tokens[idx]);
          }
        });

        // Limpiar tokens inválidos de la base de datos
        if (failedTokens.length > 0) {
          await cleanupInvalidTokens(failedTokens);
        }
      }

      // Marcar notificación como enviada
      await snapshot.ref.update({
        status: 'sent',
        sentAt: FieldValue.serverTimestamp(),
        successCount: response.successCount,
        failureCount: response.failureCount,
      });

      return null;
    } catch (error) {
      console.error(' Error al enviar notificaciones:', error);
      
      // Marcar como error
      await snapshot.ref.update({
        status: 'error',
        error: error.message,
        errorAt: FieldValue.serverTimestamp(),
      });
      
      return null;
    }
  }
);

// Función auxiliar para limpiar tokens inválidos
async function cleanupInvalidTokens(failedTokens) {
  const db = getFirestore();
  const usersRef = db.collection('users');
  
  try {
    // Procesar tokens en lotes de 10 (límite de Firestore para 'in')
    for (let i = 0; i < failedTokens.length; i += 10) {
      const batch = failedTokens.slice(i, i + 10);
      const snapshot = await usersRef
        .where('fcmToken', 'in', batch)
        .get();
      
      const writeBatch = db.batch();
      snapshot.docs.forEach(doc => {
        writeBatch.update(doc.ref, {
          fcmToken: FieldValue.delete(),
        });
      });
      
      await writeBatch.commit();
      console.log(` ${snapshot.size} tokens inválidos eliminados (lote ${i / 10 + 1})`);
    }
  } catch (error) {
    console.error('Error al limpiar tokens:', error);
  }

}

