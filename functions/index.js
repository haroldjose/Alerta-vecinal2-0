const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onRequest } = require('firebase-functions/v2/https'); //
const { defineSecret } = require('firebase-functions/params'); //
const { initializeApp } = require('firebase-admin/app');
const { getMessaging } = require('firebase-admin/messaging');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

// Inicializar Firebase Admin
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
  // Insultos directos
  'idiota', 'imbécil', 'imbecil', 'estupido', 'estúpido', 'estupida', 'estúpida',
  'mierda', 'mierdas', 'puta', 'putas', 'puto', 'putos', 'pendejo', 'pendejos',
  'pendeja', 'pendejas', 'cabron', 'cabrón', 'cabrona', 'cabrones',
  'culo', 'culos', 'culero', 'culera', 'culeros',
  'joder', 'coño', 'coño', 'marica', 'maricon', 'maricón',
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
  'animal', 'animales', // en contexto de insulto
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

// Detecta palabras ofensivas
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



const LABEL_TO_TYPE = {
  'inseguridad y delincuencia':           'inseguridad',
  'servicios básicos e infraestructura':  'serviciosBasicos',
  'contaminación y medio ambiente':       'contaminacion',
  'convivencia vecinal':                  'convivencia',
};

// analiza el lenguaje ofensivo
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
      console.log(`[checkOffensiveContent] 🚨 Local: ofensivo → ${localOffensive.join(', ')}`);
      return res.status(200).json({
        isOffensive: true,
        offensiveWords: localOffensive,
        source: 'local',
      });
    }

    // Análisis con Hugging Face usando el modelo multilingüe de clasificación de toxicidad
    const apiKey = hfApiKey.value();

    if (!apiKey) {
      console.warn('[checkOffensiveContent] HF_API_KEY no configurada, usando solo detección local.');
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

      console.log(`[checkOffensiveContent] HF score tóxico: ${toxicScore.toFixed(3)} para: "${combinedText.substring(0, 50)}..."`);

      // Umbral: si supera 0.75 de confianza, es ofensivo
      if (toxicScore >= 0.75) {
        
        const suspectWords = detectOffensiveWordsLocally(combinedText);

        return res.status(200).json({
          isOffensive: true,
          offensiveWords: suspectWords.length > 0 ? suspectWords : ['contenido inapropiado'],
          source: 'hf',
          toxicScore,
        });
      }

      // No es ofensivo
      return res.status(200).json({ isOffensive: false });

    } catch (error) {
      console.error('[checkOffensiveContent] Error inesperado:', error);
      // En caso de error de red u otro, no bloqueamos al usuario
      return res.status(200).json({ isOffensive: false });
    }
  }
);






//Sugereecia de tipo de problema con IA 
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

    // clasificar por palabras clave
    const kwResult = classifyByKeywords(combinedText);

    if (kwResult && kwResult.dominance >= 0.6 && kwResult.score >= 2) {
      const confidence = kwResult.score >= 5 ? 'alta' : kwResult.dominance >= 0.75 ? 'alta' : 'media';
      console.log(`[suggestProblemType] ✅ Keywords: "${combinedText.substring(0, 40)}..." → ${kwResult.type} (${confidence})`);
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

      console.log(`[suggestProblemType] ✅ Híbrido: "${combinedText.substring(0, 40)}..." → ${finalType} (${confidence})`);
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

  ///////////////////////////////////////////////
// Se ejecuta cada 5 minutos y reprocesa notificaciones pendientes
 exports.retryPendingNotifications = functions.pubsub
  .schedule('every 5 minutes')
  .onRun(async (context) => {
    const db = getFirestore();
    
    // Buscar documentos pending de más de 2 minutos
    const twoMinutesAgo = new Date(Date.now() - 2 * 60 * 1000);
    
    const pendingDocs = await db.collection('notifications')
      .where('status', '==', 'pending')
      .where('createdAt', '<=', twoMinutesAgo)
      .get();

    if (pendingDocs.empty) {
      console.log('No hay notificaciones pendientes');
      return null;
    }

    console.log(`Reintentando ${pendingDocs.size} notificaciones pendientes...`);

    for (const doc of pendingDocs.docs) {
      const notification = doc.data();
      const { tokens, title, body, reportId, reportType } = notification;

      if (!tokens || tokens.length === 0) {
        await doc.ref.update({ status: 'skipped', reason: 'No tokens' });
        continue;
      }

      try {
        const messaging = getMessaging();
        const response = await messaging.sendEachForMulticast({
          tokens,
          notification: { title, body },
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

        await doc.ref.update({
          status: 'sent',
          sentAt: FieldValue.serverTimestamp(),
          successCount: response.successCount,
          failureCount: response.failureCount,
          retriedAt: FieldValue.serverTimestamp(),
        });

        console.log(`Reintento exitoso para ${doc.id}: ${response.successCount}/${tokens.length}`);
      } catch (error) {
        console.error(`Error reintentando ${doc.id}:`, error);
      }
    }

    return null;
  });

}

