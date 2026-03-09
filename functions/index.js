const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { initializeApp } = require('firebase-admin/app');
const { getMessaging } = require('firebase-admin/messaging');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

initializeApp();

const hfApiKey = defineSecret('HF_API_KEY');

const KEYWORDS = {
  inseguridad: [
    'borracho', 'borrachos', 'ebrio', 'ebrios', 'drogado', 'drogados',
    'ladrón', 'ladron', 'ladrones', 'robo', 'robando', 'robaron',
    'asalto', 'asaltaron', 'asaltando', 'asaltante',
    'pelea', 'peleando', 'pelearon', 'golpes', 'golpeando',
    'violencia', 'violento', 'agresion', 'agresivo',
    'cuchillo', 'arma', 'disparo', 'pistola',
    'sospechoso', 'intruso', 'vandalismo',
    'acoso', 'amenaza', 'amenazas', 'intimidando',
    'piedras', 'botando piedras', 'tirando piedras',
    'peligroso', 'peligro', 'peligrosa',
  ],
  serviciosBasicos: [
    'agua', 'tuberia', 'tubería', 'caño', 'fuga', 'derrame',
    'sin agua', 'corte de agua', 'agua cortada',
    'luz', 'electricidad', 'poste', 'apagon', 'apagón', 'sin luz',
    'cable suelto', 'cortocircuito', 'transformador',
    'gas', 'fuga de gas', 'olor a gas',
    'bache', 'hoyo', 'hueco', 'calle rota', 'asfalto',
    'semaforo', 'semáforo', 'señal de transito',
    'alcantarilla', 'drenaje', 'desague', 'inundacion',
    'basura no recogen', 'no recogen basura', 'recoleccion',
  ],
  contaminacion: [
    'basura acumulada', 'basura tirada', 'mucha basura', 'montón de basura',
    'basura en la calle', 'basura en la esquina',
    'mal olor', 'hedor', 'pestilencia', 'apesta', 'huele mal',
    'humo', 'quemando', 'quema', 'fogata',
    'contaminacion', 'contaminación', 'toxico', 'tóxico',
    'rio contaminado', 'río contaminado', 'agua contaminada',
    'desechos', 'vertido', 'aceite derramado',
    'ruido excesivo', 'musica muy alta', 'música muy alta',
  ],
  convivencia: [
    'vecino molesta', 'vecinos molestan', 'conflicto con vecino',
    'fiesta ruidosa', 'fiesta hasta tarde', 'borrachera en casa',
    'perro suelto', 'perros sueltos', 'perro agresivo', 'perro muerde',
    'animal suelto', 'animales sueltos',
    'bloqueando entrada', 'bloqueando paso', 'doble fila',
    'mal estacionado', 'grafiti', 'graffiti', 'rayando pared',
  ],
};

const OFFENSIVE_WORDS = [
  'idiota', 'imbécil', 'imbecil', 'estupido', 'estúpido', 'estupida', 'estúpida',
  'mierda', 'mierdas', 'puta', 'putas', 'puto', 'putos', 'pendejo', 'pendejos',
  'pendeja', 'pendejas', 'cabron', 'cabrón', 'cabrona', 'cabrones',
  'culo', 'culos', 'culero', 'culera', 'culeros',
  'joder', 'coño', 'marica', 'maricon', 'maricón',
  'hdp', 'hijo de puta', 'hija de puta', 'hijos de puta',
  'chinga', 'chingada', 'chingado', 'chingados', 'chingar',
  'carajo', 'carajos', 'maldito', 'maldita', 'malditos', 'malditas',
  'asco', 'asqueroso', 'asquerosa', 'asquerosos',
  'verga', 'vergon', 'vergones',
  'pinche', 'pinches',
  'weon', 'weón', 'weona', 'weonas',
  'conchetumadre', 'ctm',
  'bastardo', 'bastarda', 'bastardos',
  'gil', 'giles', 'gila',
  'boludo', 'boluda', 'boludos',
  'pelotudo', 'pelotuda',
  'tarado', 'tarada', 'tarados',
  'bruta', 'bruto', 'brutos', 'brutas',
  'burro', 'burra', 'burros', 'burras',
  'inutil', 'inútil', 'inutiles', 'inútiles',
  'animal', 'animales',
  'bestia', 'bestias',
];

function normalize(text) {
  return text.toLowerCase()
    .replace(/á/g, 'a').replace(/é/g, 'e').replace(/í/g, 'i')
    .replace(/ó/g, 'o').replace(/ú/g, 'u').replace(/ü/g, 'u')
    .replace(/ñ/g, 'n');
}

function classifyByKeywords(text) {
  const normalized = normalize(text);
  const scores = {};
  for (const [type, keywords] of Object.entries(KEYWORDS)) {
    let score = 0;
    for (const kw of keywords) {
      if (normalized.includes(normalize(kw))) {
        score += kw.split(' ').length > 1 ? 3 : 1;
      }
    }
    if (score > 0) scores[type] = score;
  }
  if (Object.keys(scores).length === 0) return null;
  const sorted = Object.entries(scores).sort((a, b) => b[1] - a[1]);
  const winner = sorted[0];
  const total = Object.values(scores).reduce((a, b) => a + b, 0);
  const dominance = winner[1] / total;
  return { type: winner[0], score: winner[1], dominance };
}

function detectOffensiveWordsLocally(text) {
  const normalizedText = normalize(text);
  const found = [];
  for (const word of OFFENSIVE_WORDS) {
    const normalizedWord = normalize(word);
    const regex = new RegExp(`(^|\\s|[^a-záéíóúüñ])${normalizedWord}([^a-záéíóúüñ]|$)`, 'i');
    if (regex.test(normalizedText) && !found.includes(word)) {
      found.push(word);
    }
  }
  return found;
}

//
const STOPWORDS = new Set([
  'para', 'como', 'pero', 'este', 'esta', 'esto', 'estos', 'estas',
  'tiene', 'hace', 'desde', 'hasta', 'entre', 'sobre',
  'porque', 'cuando', 'donde', 'mientras', 'aunque', 'tambien',
  'muy', 'mas', 'por', 'que', 'con', 'una', 'uno', 'los', 'las',
  'del', 'hay', 'han', 'sido', 'estan', 'cada', 'todo',
  'sigue', 'deja', 'vuelve', 'tiene', 'tenia', 'habia',
  'son', 'fue', 'ser', 'sus', 'nos', 'les', 'les', 'mis',
  'dia', 'vez', 'aun', 'asi', 'tan', 'sin', 'bien',
  'otro', 'otra', 'unos', 'unas', 'ese', 'esa', 'esos', 'esas',
]);

function tokenize(text) {
  return normalize(text)
    .replace(/[^a-z0-9\s]/g, ' ')
    .split(/\s+/)
    .filter(w => w.length >= 3 && !STOPWORDS.has(w));
}

function jaccardSimilarity(textA, textB) {
  const setA = new Set(tokenize(textA));
  const setB = new Set(tokenize(textB));

  if (setA.size === 0 && setB.size === 0) return 0;

  const intersection = new Set([...setA].filter(w => setB.has(w)));
  const union = new Set([...setA, ...setB]);

  return intersection.size / union.size;
}


// Llama al pipeline SentenceSimilarity de HF.
async function getSimilarityScores(sourceSentence, sentences, apiKey) {
  const url = 'https://router.huggingface.co/hf-inference/models/sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2';

  const fetchHF = () => fetch(url, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      inputs: {
        source_sentence: sourceSentence,
        sentences: sentences,
      },
    }),
  });

  let response = await fetchHF();

  if (response.status === 503) {
    const body = await response.json().catch(() => ({}));
    const wait = Math.min((body.estimated_time || 20) * 1000, 20000);
    console.log(`[getSimilarityScores] Modelo cargando, esperando ${wait}ms...`);
    await new Promise(r => setTimeout(r, wait));
    response = await fetchHF();
  }

  if (!response.ok) {
    const err = await response.text();
    throw new Error(`HF similarity error ${response.status}: ${err}`);
  }

  const data = await response.json();

  if (!Array.isArray(data)) throw new Error('Respuesta inesperada de HF similarity');
  return data;
}

function cosineSimilarity(vecA, vecB) {
  let dot = 0, normA = 0, normB = 0;
  for (let i = 0; i < vecA.length; i++) {
    dot   += vecA[i] * vecB[i];
    normA += vecA[i] * vecA[i];
    normB += vecB[i] * vecB[i];
  }
  if (normA === 0 || normB === 0) return 0;
  return dot / (Math.sqrt(normA) * Math.sqrt(normB));
}

// Umbrales ajustables.
const JACCARD_THRESHOLD = 0.10;  
const COSINE_THRESHOLD  = 0.70;

exports.checkDuplicateReport = onRequest(
  {
    cors: true,
    timeoutSeconds: 60,
    region: 'us-central1',
    secrets: [hfApiKey],
  },
  async (req, res) => {
    if (req.method !== 'POST') {
      return res.status(405).json({ error: 'Método no permitido. Use POST.' });
    }

    const {
      title = '',
      description = '',
      location = null,
      excludeReportId = null,  
    } = req.body;

    const newText = `${title.trim()} ${description.trim()}`.trim();

    if (newText.length < 5) {
      return res.status(400).json({ error: 'Texto insuficiente.' });
    }

    const db = getFirestore();

    const cutoff = new Date(Date.now() - 48 * 60 * 60 * 1000);

    let snapshot;
    try {
      snapshot = await db.collection('reports')
        .where('createdAt', '>=', cutoff)
        .orderBy('createdAt', 'desc')
        .limit(100)
        .get();
    } catch (err) {
      console.error('[checkDuplicate] Error Firestore:', err);
      
      return res.status(200).json({ isDuplicate: false });
    }

    
    const existingReports = snapshot.docs
      .filter(doc => doc.id !== excludeReportId)
      .map(doc => {
        const d = doc.data();
        return {
          id:          doc.id,
          title:       d.title       || '',
          description: d.description || '',
          problemType: d.problemType || '',
          createdAt:   d.createdAt?.toDate?.()?.toISOString() || '',
          location:    d.location    || null,
          userName:    d.userName    || 'Usuario',
          status:      d.status      || 'pendiente',
        };
      });

    console.log(`[checkDuplicate] Reportes en las últimas 48 h: ${existingReports.length}`);

    if (existingReports.length === 0) {
      return res.status(200).json({ isDuplicate: false });
    }

    
    const candidates = existingReports
      .map(r => ({
        report:    r,
        jaccard:   jaccardSimilarity(newText, `${r.title} ${r.description}`),
      }))
      .filter(c => c.jaccard >= JACCARD_THRESHOLD)
      .sort((a, b) => b.jaccard - a.jaccard)
      .slice(0, 10);  

    console.log(`[checkDuplicate] Candidatos tras pre-filtro Jaccard (≥${JACCARD_THRESHOLD}): ${candidates.length}`);

    if (candidates.length === 0) {
      return res.status(200).json({ isDuplicate: false });
    }

    const apiKey = hfApiKey.value();

    if (!apiKey) {
      console.warn('[checkDuplicate] HF_API_KEY no configurada. Usando score Jaccard.');
      const best = candidates[0];
      if (best.jaccard >= 0.45) {
        return res.status(200).json({
          isDuplicate: true,
          similarReport: { ...best.report, similarity: Math.round(best.jaccard * 100) },
        });
      }
      return res.status(200).json({ isDuplicate: false });
    }

    const candidateSentences = candidates.map(
      c => `${c.report.title} ${c.report.description}`
    );

    let scores;
    try {
      scores = await getSimilarityScores(newText, candidateSentences, apiKey);
      console.log(`[checkDuplicate] Scores HF: ${scores.map(s => s.toFixed(3)).join(', ')}`);
    } catch (err) {
      console.error('[checkDuplicate] Error HF similarity:', err.message);
      
      return res.status(200).json({ isDuplicate: false });
    }

    let bestMatch = null;
    let bestScore = 0;

    scores.forEach((score, i) => {
      if (score > bestScore) {
        bestScore = score;
        bestMatch = candidates[i].report;
      }
    });

    console.log(`[checkDuplicate] Mejor score HF: ${bestScore.toFixed(3)} (umbral: ${COSINE_THRESHOLD})`);

    // Devolver resultado
    if (bestMatch && bestScore >= COSINE_THRESHOLD) {
      return res.status(200).json({
        isDuplicate: true,
        similarReport: {
          id:          bestMatch.id,
          title:       bestMatch.title,
          description: bestMatch.description,
          problemType: bestMatch.problemType,
          createdAt:   bestMatch.createdAt,
          userName:    bestMatch.userName,
          status:      bestMatch.status,
          similarity:  Math.round(bestScore * 100),
        },
      });
    }

    return res.status(200).json({ isDuplicate: false });
  }
);

const LABEL_TO_TYPE = {
  'inseguridad y delincuencia':           'inseguridad',
  'servicios básicos e infraestructura':  'serviciosBasicos',
  'contaminación y medio ambiente':       'contaminacion',
  'convivencia vecinal':                  'convivencia',
};

exports.checkOffensiveContent = onRequest(
  {
    cors: true,
    timeoutSeconds: 60,
    region: 'us-central1',
    secrets: [hfApiKey],
  },
  async (req, res) => {
    if (req.method !== 'POST') {
      return res.status(405).json({ error: 'Método no permitido. Use POST.' });
    }

    const { title = '', description = '' } = req.body;
    const combinedText = `${title} ${description}`.trim();

    if (combinedText.length < 2) {
      return res.status(400).json({ error: 'Texto insuficiente.' });
    }

    const localOffensive = detectOffensiveWordsLocally(combinedText);

    if (localOffensive.length > 0) {
      console.log(`[checkOffensiveContent] Local ofensivo → ${localOffensive.join(', ')}`);
      return res.status(200).json({
        isOffensive: true,
        offensiveWords: localOffensive,
        source: 'local',
      });
    }

    const apiKey = hfApiKey.value();

    if (!apiKey) {
      console.warn('[checkOffensiveContent] HF_API_KEY no configurada.');
      return res.status(200).json({ isOffensive: false });
    }

    try {
      const hfUrl = 'https://router.huggingface.co/hf-inference/models/s-nlp/roberta_toxicity_classifier';

      const fetchHF = () => fetch(hfUrl, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ inputs: combinedText }),
      });

      let response = await fetchHF();

      if (response.status === 503) {
        const body = await response.json().catch(() => ({}));
        const waitTime = Math.min((body.estimated_time || 15) * 1000, 15000);
        console.log(`[checkOffensiveContent] Modelo cargando, esperando ${waitTime}ms...`);
        await new Promise(resolve => setTimeout(resolve, waitTime));
        response = await fetchHF();
      }

      if (!response.ok) {
        const errText = await response.text();
        console.error('[checkOffensiveContent] Error HF:', errText);
        return res.status(200).json({ isOffensive: false });
      }

      const hfData = await response.json();
      const results = Array.isArray(hfData[0]) ? hfData[0] : hfData;
      const toxicResult = results.find(r => r.label === 'toxic');
      const toxicScore = toxicResult ? toxicResult.score : 0;

      console.log(`[checkOffensiveContent] HF score tóxico: ${toxicScore.toFixed(3)}`);

      if (toxicScore >= 0.75) {
        const suspectWords = detectOffensiveWordsLocally(combinedText);
        return res.status(200).json({
          isOffensive: true,
          offensiveWords: suspectWords.length > 0 ? suspectWords : ['contenido inapropiado'],
          source: 'hf',
          toxicScore,
        });
      }

      return res.status(200).json({ isOffensive: false });

    } catch (error) {
      console.error('[checkOffensiveContent] Error inesperado:', error);
      return res.status(200).json({ isOffensive: false });
    }
  }
);

exports.suggestProblemType = onRequest(
  {
    cors: true,
    timeoutSeconds: 60,
    region: 'us-central1',
    secrets: [hfApiKey],
  },
  async (req, res) => {
    if (req.method !== 'POST') {
      return res.status(405).json({ error: 'Método no permitido. Use POST.' });
    }

    const { title = '', description = '' } = req.body;
    const combinedText = `${title} ${description}`.trim();

    if (combinedText.length < 5) {
      return res.status(400).json({ error: 'Texto insuficiente.' });
    }

    const kwResult = classifyByKeywords(combinedText);

    if (kwResult && kwResult.dominance >= 0.6 && kwResult.score >= 2) {
      const confidence = kwResult.score >= 5 ? 'alta' : kwResult.dominance >= 0.75 ? 'alta' : 'media';
      return res.status(200).json({
        suggestion: kwResult.type,
        confidence,
        reason: `Detectado por palabras clave con ${Math.round(kwResult.dominance * 100)}% de certeza.`,
      });
    }

    const apiKey = hfApiKey.value();
    if (!apiKey) {
      if (kwResult) {
        return res.status(200).json({
          suggestion: kwResult.type,
          confidence: 'baja',
          reason: 'Clasificación aproximada por palabras clave.',
        });
      }
      return res.status(500).json({ error: 'Servicio de IA no configurado.' });
    }

    try {
      const hfUrl = 'https://router.huggingface.co/hf-inference/models/joeddav/xlm-roberta-large-xnli';

      const hfBody = JSON.stringify({
        inputs: combinedText,
        parameters: {
          candidate_labels: [
            'inseguridad y delincuencia',
            'servicios básicos e infraestructura',
            'contaminación y medio ambiente',
            'convivencia vecinal',
          ],
          multi_label: false,
        },
      });

      const fetchHF = () => fetch(hfUrl, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${apiKey}`,
          'Content-Type': 'application/json',
        },
        body: hfBody,
      });

      let response = await fetchHF();

      if (response.status === 503) {
        const body = await response.json();
        const waitTime = Math.min((body.estimated_time || 20) * 1000, 20000);
        await new Promise(resolve => setTimeout(resolve, waitTime));
        response = await fetchHF();
      }

      if (!response.ok) {
        const errText = await response.text();
        console.error('[suggestProblemType] Error HF:', errText);
        if (kwResult) {
          return res.status(200).json({
            suggestion: kwResult.type,
            confidence: 'baja',
            reason: 'Clasificación por palabras clave (IA no disponible).',
          });
        }
        return res.status(502).json({ error: 'Error al consultar el servicio de IA.' });
      }

      const hfData = await response.json();
      const labels = hfData.labels || [];
      const scores = hfData.scores || [];

      if (labels.length === 0) {
        return res.status(502).json({ error: 'Respuesta vacía del servicio de IA.' });
      }

      const hfType = LABEL_TO_TYPE[labels[0]] || 'inseguridad';
      const hfScore = scores[0];

      let finalType = hfType;
      let confidence;
      let reason;

      if (kwResult && kwResult.type !== hfType) {
        if (kwResult.dominance >= 0.7) {
          finalType = kwResult.type;
          confidence = 'media';
          reason = `Palabras clave sugieren "${finalType}" con alta certeza.`;
        } else {
          finalType = hfType;
          confidence = hfScore >= 0.45 ? 'media' : 'baja';
          reason = `Clasificado como "${labels[0]}" con ${Math.round(hfScore * 100)}% de certeza.`;
        }
      } else {
        confidence = hfScore >= 0.45 || (kwResult && kwResult.score >= 3) ? 'alta' : 'media';
        reason = `Clasificado como "${labels[0]}" con ${Math.round(hfScore * 100)}% de certeza.`;
      }

      return res.status(200).json({ suggestion: finalType, confidence, reason });

    } catch (error) {
      console.error('[suggestProblemType] Error inesperado:', error);
      if (kwResult) {
        return res.status(200).json({
          suggestion: kwResult.type,
          confidence: 'baja',
          reason: 'Clasificación por palabras clave (error de IA).',
        });
      }
      return res.status(500).json({ error: 'Error interno del servidor.' });
    }
  }
);

exports.sendReportNotification = onDocumentCreated(
  'notifications/{notificationId}',
  async (event) => {
    const snapshot = event.data;

    if (!snapshot) {
      console.log('No hay datos en el snapshot');
      return null;
    }

    const notification = snapshot.data();

    if (notification.status !== 'pending') {
      console.log('Notificación ya procesada, saltando...');
      return null;
    }

    const { tokens, title, body, reportId, reportType } = notification;

    if (!tokens || tokens.length === 0) {
      console.log('No hay tokens para enviar notificaciones');
      await snapshot.ref.update({ status: 'skipped', reason: 'No tokens available' });
      return null;
    }

    console.log(`Enviando notificación [${reportType ?? 'sin categoría'}] a ${tokens.length} dispositivo(s)...`);

    try {
      const messaging = getMessaging();

      const response = await messaging.sendEachForMulticast({
        tokens: tokens,
        notification: { title: title, body: body },
        data: {
          reportId: reportId || '',
          reportType: reportType || '',
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        android: {
          priority: 'high',
          notification: { channelId: 'reports_channel', sound: 'default', color: '#D63031' },
        },
        apns: { payload: { aps: { sound: 'default', badge: 1 } } },
      });

      console.log(`Notificaciones enviadas: ${response.successCount}/${tokens.length}`);

      if (response.failureCount > 0) {
        const failedTokens = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            console.error(`Token ${tokens[idx]} falló:`, resp.error);
            failedTokens.push(tokens[idx]);
          }
        });
        if (failedTokens.length > 0) {
          await cleanupInvalidTokens(failedTokens);
        }
      }

      await snapshot.ref.update({
        status: 'sent',
        sentAt: FieldValue.serverTimestamp(),
        successCount: response.successCount,
        failureCount: response.failureCount,
      });

      return null;
    } catch (error) {
      console.error('Error al enviar notificaciones:', error);
      await snapshot.ref.update({
        status: 'error',
        error: error.message,
        errorAt: FieldValue.serverTimestamp(),
      });
      return null;
    }
  }
);

async function cleanupInvalidTokens(failedTokens) {
  const db = getFirestore();
  const usersRef = db.collection('users');

  try {
    for (let i = 0; i < failedTokens.length; i += 10) {
      const batch = failedTokens.slice(i, i + 10);
      const snapshot = await usersRef.where('fcmToken', 'in', batch).get();

      const writeBatch = db.batch();
      snapshot.docs.forEach(doc => {
        writeBatch.update(doc.ref, { fcmToken: FieldValue.delete() });
      });

      await writeBatch.commit();
      console.log(`${snapshot.size} tokens inválidos eliminados`);
    }
  } catch (error) {
    console.error('Error al limpiar tokens:', error);
  }
}

