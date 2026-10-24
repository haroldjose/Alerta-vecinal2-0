const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

// Códigos de FCM que indican que el token 
const INVALID_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

// 'servicios_basicos' (preferencias) y 'serviciosBasicos' (tipo de reporte)
// son la misma categoría: se comparan sin guiones bajos ni mayúsculas.
function normalizeCategory(value) {
  return String(value || '').replace(/[_\s]/g, '').toLowerCase();
}

// Misma lógica que antes hacía la app: sin preferencias = recibe todo.
function wantsReport(prefs, reportType) {
  if (!prefs) return true;
  if (prefs.enabled === false) return false;
  if (prefs.allCategories !== false) return true;
  const selected = Array.isArray(prefs.selectedCategories) ? prefs.selectedCategories : [];
  const target = normalizeCategory(reportType);
  return selected.some((c) => normalizeCategory(c) === target);
}


// Calcula los destinatarios en el servidor y envía la notificación.
 
exports.notifyOnReportCreated = onDocumentCreated('reports/{reportId}', async (event) => {
  const snapshot = event.data;
  if (!snapshot) return null;

  const report = snapshot.data();
  const reportId = event.params.reportId;
  const reportType = report.problemType || '';
  const reportTitle = report.title || '';
  const creatorId = report.userId;

  const db = getFirestore();
  const usersSnap = await db.collection('users').where('fcmToken', '!=', null).get();

  const recipients = []; // { token, ref }
  usersSnap.docs.forEach((doc) => {
    if (doc.id === creatorId) return;
    const data = doc.data();
    const token = data.fcmToken;
    if (typeof token !== 'string' || token.length === 0) return;
    if ((data.role || 'vecino') === 'security') return; // seguridad no recibe
    if (!wantsReport(data.notificationPreferences, reportType)) return;
    recipients.push({ token, ref: doc.ref });
  });

  if (recipients.length === 0) {
    console.log(`Sin destinatarios para el reporte (${reportType || 'sin categoría'}).`);
    return null;
  }

  const messaging = getMessaging();
  const invalidRefs = [];
  let success = 0;
  let failure = 0;

  // FCM admite hasta 500 tokens por envío
  for (let i = 0; i < recipients.length; i += 500) {
    const chunk = recipients.slice(i, i + 500);
    const response = await messaging.sendEachForMulticast({
      tokens: chunk.map((r) => r.token),
      notification: { title: `Nuevo Reporte: ${reportType}`, body: reportTitle },
      data: {
        reportId,
        reportType,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      android: {
        priority: 'high',
        notification: { channelId: 'reports_channel', sound: 'default', color: '#D63031' },
      },
      apns: { payload: { aps: { sound: 'default', badge: 1 } } },
    });

    success += response.successCount;
    failure += response.failureCount;

    response.responses.forEach((resp, idx) => {
      if (!resp.success && INVALID_TOKEN_CODES.has(resp.error?.code)) {
        invalidRefs.push(chunk[idx].ref); // no se registra el token en los logs
      }
    });
  }

  console.log(`Notificaciones enviadas: ${success}/${recipients.length} (fallidas: ${failure}).`);

  if (invalidRefs.length > 0) {
    const batch = db.batch();
    invalidRefs.forEach((ref) => batch.update(ref, { fcmToken: FieldValue.delete() }));
    await batch.commit();
    console.log(`${invalidRefs.length} tokens inválidos eliminados.`);
  }

  return null;
});