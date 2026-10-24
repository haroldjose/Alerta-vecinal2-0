const { onRequest } = require('firebase-functions/v2/https');
const { getFirestore } = require('firebase-admin/firestore');

// Letras (con tildes y ñ) y dígitos, de 2 a 40 caracteres
const USERNAME_RE = /^[A-Za-zÁÉÍÓÚáéíóúÑñ0-9]{2,40}$/;

// Límite sencillo por IP (20 solicitudes por minuto).
const WINDOW_MS = 60 * 1000;
const MAX_PER_WINDOW = 20;
const hits = new Map();

function tooManyRequests(ip) {
  const now = Date.now();
  if (hits.size > 1000) hits.clear();
  const recent = (hits.get(ip) || []).filter((t) => now - t < WINDOW_MS);
  recent.push(now);
  hits.set(ip, recent);
  return recent.length > MAX_PER_WINDOW;
}

exports.resolveLogin = onRequest(
  {
    cors: false,
    region: 'us-central1',
    maxInstances: 5,
    timeoutSeconds: 15,
  },
  async (req, res) => {
    if (req.method !== 'POST') {
      return res.status(405).json({ error: 'Método no permitido. Use POST.' });
    }

    const forwarded = (req.get('x-forwarded-for') || '').split(',')[0].trim();
    const ip = forwarded || req.ip || 'desconocida';
    if (tooManyRequests(ip)) {
      return res.status(429).json({ error: 'Demasiadas solicitudes. Intenta más tarde.' });
    }

    const username = req.body && req.body.username;
    if (typeof username !== 'string' || !USERNAME_RE.test(username)) {
      return res.status(404).json({ error: 'not_found' });
    }

    try {
      const snap = await getFirestore()
        .collection('users')
        .where('username', '==', username)
        .limit(1)
        .get();

      if (snap.empty) {
        return res.status(404).json({ error: 'not_found' });
      }

      const email = snap.docs[0].data().email;
      if (typeof email !== 'string' || email.length === 0) {
        return res.status(404).json({ error: 'not_found' });
      }

      return res.status(200).json({ email });
    } catch (err) {
      console.error('[resolveLogin] Error:', err.message);
      return res.status(500).json({ error: 'Error interno del servidor.' });
    }
  }
);