const { onRequest } = require('firebase-functions/v2/https');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');
const { requireAuth } = require('./security');

const OPTIONS = { cors: false, maxInstances: 10, timeoutSeconds: 30, region: 'us-central1' };
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const DIGITS_RE = /^\d{1,8}$/;
const UID_RE = /^[A-Za-z0-9_-]{1,128}$/;

function isText(v, max) {
  return typeof v === 'string' && v.trim().length > 0 && v.length <= max;
}

function strongPassword(p) {
  return typeof p === 'string' && p.length >= 14 && p.length <= 128
    && /[A-Z]/.test(p) && /[a-z]/.test(p) && /\d/.test(p) && /[^A-Za-z0-9]/.test(p);
}

async function authorize(req, res) {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Método no permitido. Use POST.' });
    return null;
  }

  const decoded = await requireAuth(req, res);
  if (!decoded) return null;

  const db = getFirestore();
  const caller = await db.doc(`users/${decoded.uid}`).get();
  if (caller.data()?.role !== 'security') {
    res.status(403).json({ error: 'No autorizado.' });
    return null;
  }

  const body = req.body;
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    res.status(400).json({ error: 'Cuerpo inválido.' });
    return null;
  }

  const uid = body.uid;
  if (typeof uid !== 'string' || !UID_RE.test(uid) || uid === decoded.uid) {
    res.status(400).json({ error: 'Usuario inválido.' });
    return null;
  }

  const ref = db.doc(`users/${uid}`);
  const snap = await ref.get();
  if (!snap.exists) {
    res.status(404).json({ error: 'Usuario no encontrado.' });
    return null;
  }

  const target = snap.data();
  if ((target.createdBy && target.createdBy !== decoded.uid) || target.role === 'security') {
    res.status(403).json({ error: 'Solo puedes gestionar usuarios que tú creaste.' });
    return null;
  }

  return { db, ref, uid, body };
}

exports.updateManagedUser = onRequest(OPTIONS, async (req, res) => {
  try {
    const ctx = await authorize(req, res);
    if (!ctx) return;
    const { db, ref, uid, body } = ctx;
    const { name, cedula, celular, email, username, password } = body;

    if (!isText(name, 100) || !isText(username, 50)
        || typeof cedula !== 'string' || !DIGITS_RE.test(cedula)
        || typeof celular !== 'string' || !DIGITS_RE.test(celular)
        || typeof email !== 'string' || !EMAIL_RE.test(email.trim())) {
      return res.status(400).json({ error: 'Datos inválidos.' });
    }

    const hasPassword = password !== undefined && password !== null && password !== '';
    if (hasPassword && !strongPassword(password)) {
      return res.status(400).json({ error: 'La contraseña no cumple los requisitos.' });
    }

    const dup = await db.collection('users').where('username', '==', username).limit(2).get();
    if (dup.docs.some((d) => d.id !== uid)) {
      return res.status(409).json({ error: 'El nombre de usuario ya está en uso.' });
    }

    const authUpdate = { email: email.trim(), displayName: name.trim() };
    if (hasPassword) authUpdate.password = password;

    try {
      await getAuth().updateUser(uid, authUpdate);
    } catch (err) {
      if (err.code === 'auth/email-already-exists') {
        return res.status(409).json({ error: 'Este email ya está registrado.' });
      }
      throw err;
    }

    await ref.update({
      name: name.trim(),
      cedula,
      celular,
      email: email.trim(),
      username,
    });

    return res.status(200).json({ ok: true });
  } catch (err) {
    console.error('[updateManagedUser]', err);
    return res.status(500).json({ error: 'Error interno del servidor.' });
  }
});

exports.deleteManagedUser = onRequest(OPTIONS, async (req, res) => {
  try {
    const ctx = await authorize(req, res);
    if (!ctx) return;
    const { ref, uid } = ctx;

    try {
      await getAuth().deleteUser(uid);
    } catch (err) {
      if (err.code !== 'auth/user-not-found') throw err;
    }
    await ref.delete();

    return res.status(200).json({ ok: true });
  } catch (err) {
    console.error('[deleteManagedUser]', err);
    return res.status(500).json({ error: 'Error interno del servidor.' });
  }
});