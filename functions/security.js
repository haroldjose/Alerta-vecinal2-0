const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');

const MAX_TITLE = 200;
const MAX_DESCRIPTION = 3000;
const MAX_BODY_BYTES = 20 * 1024; // 20 KB sobran para un reporte de texto


//  Exige un token de Firebase y que el usuario tenga perfil en la colección "users" 
 
async function requireAuth(req, res) {
  const header = req.get('Authorization') || '';
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    res.status(401).json({ error: 'No autenticado.' });
    return null;
  }

  let decoded;
  try {
    decoded = await getAuth().verifyIdToken(match[1]);
  } catch (_) {
    res.status(401).json({ error: 'Token inválido o expirado.' });
    return null;
  }

  try {
    const profile = await getFirestore().doc(`users/${decoded.uid}`).get();
    if (!profile.exists) {
      res.status(403).json({ error: 'Usuario sin perfil registrado.' });
      return null;
    }
  } catch (err) {
    console.error('[requireAuth] Error al verificar perfil:', err.message);
    res.status(500).json({ error: 'Error interno del servidor.' });
    return null;
  }

  return decoded;
}

// Valida el cuerpo de las funciones de texto: tipos, largos y tamaño. Devuelve { title, description, excludeReportId, location } o null

function readTextBody(req, res) {
  const declaredSize = Number(req.get('content-length') || 0);
  if (declaredSize > MAX_BODY_BYTES) {
    res.status(413).json({ error: 'Solicitud demasiado grande.' });
    return null;
  }

  const body = req.body;
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    res.status(400).json({ error: 'Cuerpo inválido.' });
    return null;
  }

  const {
    title = '',
    description = '',
    excludeReportId = null,
    location = null,
  } = body;

  if (typeof title !== 'string' || typeof description !== 'string') {
    res.status(400).json({ error: 'Título y descripción deben ser texto.' });
    return null;
  }
  if (title.length > MAX_TITLE || description.length > MAX_DESCRIPTION) {
    res.status(400).json({ error: 'Texto demasiado largo.' });
    return null;
  }
  if (
    excludeReportId !== null &&
    (typeof excludeReportId !== 'string' || excludeReportId.length > 100)
  ) {
    res.status(400).json({ error: 'excludeReportId inválido.' });
    return null;
  }
  if (location !== null && (typeof location !== 'object' || Array.isArray(location))) {
    res.status(400).json({ error: 'location inválida.' });
    return null;
  }

  return { title, description, excludeReportId, location };
}

module.exports = { requireAuth, readTextBody };