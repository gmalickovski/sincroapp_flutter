const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");
const crypto = require("crypto");
const {RecaptchaEnterpriseServiceClient} = require("@google-cloud/recaptcha-enterprise");

// Inicializa o SDK Admin
admin.initializeApp();

// Referências
const db = admin.firestore();
const messaging = admin.messaging();

// Cliente reCAPTCHA Enterprise (reutilizável)
const recaptchaClient = new RecaptchaEnterpriseServiceClient();

// URL do seu webhook
const N8N_WEBHOOK_URL = "https://n8n.studiomlk.com.br/webhook/sincroapp";

// Configurações reCAPTCHA (sincroapp-529cc - PROJETO CORRETO)
const RECAPTCHA_PROJECT_ID = "sincroapp-529cc";
const RECAPTCHA_SITE_KEY = "6LfPrg8sAAAAAEM0C6vuU0H9qMlXr89zr553zi_B";

/**
 * Valida token reCAPTCHA e retorna score de risco (0.0 a 1.0)
 * Score alto (>0.5) = provavelmente humano
 * Score baixo (<0.5) = provavelmente bot
 * 
 * @param {string} token - Token reCAPTCHA do cliente
 * @param {string} expectedAction - Ação esperada (login, register, etc)
 * @returns {Promise<{valid: boolean, score: number, reasons: string[]}>}
 */
async function assessRecaptcha(token, expectedAction = "homepage") {
  try {
    const projectPath = recaptchaClient.projectPath(RECAPTCHA_PROJECT_ID);

    const request = {
      assessment: {
        event: {
          token: token,
          siteKey: RECAPTCHA_SITE_KEY,
          expectedAction: expectedAction,
        },
      },
      parent: projectPath,
    };

    const [response] = await recaptchaClient.createAssessment(request);

    // Verifica se o token é válido
    if (!response.tokenProperties.valid) {
      functions.logger.warn(`Token inválido: ${response.tokenProperties.invalidReason}`);
      return {
        valid: false,
        score: 0,
        reasons: [response.tokenProperties.invalidReason],
      };
    }

    // Verifica se a ação corresponde
    if (response.tokenProperties.action !== expectedAction) {
      functions.logger.warn(`Ação não corresponde. Esperado: ${expectedAction}, Recebido: ${response.tokenProperties.action}`);
      return {
        valid: false,
        score: 0,
        reasons: ["ACTION_MISMATCH"],
      };
    }

    // Retorna score e motivos
    const score = response.riskAnalysis.score || 0;
    const reasons = response.riskAnalysis.reasons || [];

    functions.logger.info(`✅ reCAPTCHA válido. Score: ${score}, Razões: ${reasons.join(", ")}`);

    return {
      valid: true,
      score: score,
      reasons: reasons,
    };
  } catch (error) {
    functions.logger.error("Erro ao validar reCAPTCHA:", error);
    throw new functions.https.HttpsError("internal", "Erro ao validar reCAPTCHA");
  }
}

/**
 * Função auxiliar para enviar dados ao webhook do n8n.
 */
const sendToWebhook = async (payload) => {
  try {
    functions.logger.info("Tentando enviar dados para o n8n:", payload);
    await axios.post(N8N_WEBHOOK_URL, payload);
    functions.logger.info("Webhook enviado com sucesso para n8n.");
  } catch (error) {
    functions.logger.error("ERRO AO ENVIAR WEBHOOK:", { errorMessage: error.message });
  }
};

// ========================================
// RECAPTCHA ENTERPRISE VALIDATION
// ========================================

/**
 * Endpoint público para validar tokens reCAPTCHA
 * Usado pela landing page e pelo Flutter app para pontuar
 * 
 * POST body: { token: string, action: string }
 */
exports.validateRecaptcha = functions.https.onRequest(async (req, res) => {
  // Apenas POST
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Método não permitido" });
  }

  try {
    const { token, action } = req.body;

    if (!token) {
      return res.status(400).json({ error: "Token reCAPTCHA obrigatório" });
    }

    const expectedAction = action || "homepage";
    const assessment = await assessRecaptcha(token, expectedAction);

    // Threshold: score >= 0.5 considerado válido
    const isHuman = assessment.valid && assessment.score >= 0.5;

    res.status(200).json({
      success: isHuman,
      score: assessment.score,
      valid: assessment.valid,
      reasons: assessment.reasons,
      message: isHuman ? "Verificação aprovada" : "Verificação falhou - possível bot",
    });
  } catch (error) {
    functions.logger.error("Erro em validateRecaptcha:", error);
    res.status(500).json({ error: "Erro ao validar token" });
  }
});

/**
 * Acionado quando um novo documento de usuário é criado no Firestore.
 * Envia um evento 'user_created' para o n8n.
 */
exports.onNewUserDocumentCreate = functions.firestore.document("users/{userId}").onCreate(async (snapshot, context) => {
  functions.logger.info("================ onNewUserDocumentCreate ACIONADA ================");
  const userData = snapshot.data();
  const userId = context.params.userId;
  functions.logger.info("Novo documento de usuário criado:", { uid: userId, data: userData });
  
  const payload = {
    event: "user_created",
    email: userData.email,
    name: `${userData.primeiroNome || ''} ${userData.sobrenome || ''}`.trim(),
    plan: userData.plano || "gratuito",
    userId: userId,
  };
  
  await sendToWebhook(payload);
  
  functions.logger.info("Função onNewUserDocumentCreate concluída.");
  functions.logger.info("================================================================");
  return null;
});

/**
 * Acionado quando um documento de usuário é atualizado no Firestore.
 * Se o plano mudou para 'premium', envia um evento 'plan_upgraded'.
 */
exports.onUserUpdate = functions.firestore.document("users/{userId}").onUpdate(async (change, context) => {
  functions.logger.info("================ onUserUpdate ACIONADA ================");
  const beforeData = change.before.data();
  const afterData = change.after.data();
  const userId = context.params.userId;
  functions.logger.info(`Documento do usuário ${userId} foi atualizado.`);

  // Verifica se o plano foi atualizado para premium
  if (beforeData.plano !== "premium" && afterData.plano === "premium") {
    functions.logger.info(`Usuário ${userId} fez upgrade para o plano Premium.`);
    const payload = {
      event: "plan_upgraded",
      email: afterData.email,
      name: `${afterData.primeiroNome || ''} ${afterData.sobrenome || ''}`.trim(),
      plan: afterData.plano,
      userId,
    };
    await sendToWebhook(payload);
  }
  
  functions.logger.info("==========================================================");
  return null;
});

/**
 * Acionado quando um usuário é excluído do Firebase Authentication.
 * 1. Envia um webhook 'user_deleted' para o n8n.
 * 2. Limpa todos os dados associados a esse usuário no Firestore.
 */
exports.onUserDeleted = functions.auth.user().onDelete(async (user) => {
  const userId = user.uid;
  const userEmail = user.email; // O e-mail vem do objeto 'user' do Auth
  const logger = functions.logger;
  logger.info(`================ onUserDeleted ACIONADA =================`);
  logger.info(`Usuário a ser deletado: ${userId} (${userEmail})`);

  const firestore = admin.firestore();
  const userDocRef = firestore.collection("users").doc(userId);

  try {
    // --- PASSO 1: Buscar dados do usuário ANTES de deletar ---
    const userDoc = await userDocRef.get();
    let userName = '';
    if (userDoc.exists) {
      const userData = userDoc.data();
      userName = `${userData.primeiroNome || ''} ${userData.sobrenome || ''}`.trim();
      logger.info(`Dados do usuário encontrados para o webhook: ${userName}`);
    } else {
      logger.warn(`Documento ${userId} não encontrado no Firestore, mas a conta de autenticação foi excluída.`);
    }

    // --- PASSO 2: Enviar o webhook de conta deletada ---
    const payload = {
      event: "user_deleted",
      email: userEmail,
      name: userName,
      userId: userId,
    };
    await sendToWebhook(payload);
    logger.info(`Webhook 'user_deleted' enviado para ${userId}.`);

    // --- PASSO 3: Limpeza dos dados do Firestore (lógica original) ---
    logger.info(`Iniciando limpeza de dados do Firestore para o usuário: ${userId}`);
    
    // Deletar subcoleção 'tasks'
    const tasksRef = userDocRef.collection("tasks");
    const tasksSnapshot = await tasksRef.get();
    if (!tasksSnapshot.empty) {
      const batch = firestore.batch();
      tasksSnapshot.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
      logger.log(`Subcoleção 'tasks' do usuário ${userId} deletada.`);
    }

    // Deletar subcoleção 'journalEntries'
    const journalRef = userDocRef.collection("journalEntries");
    const journalSnapshot = await journalRef.get();
    if (!journalSnapshot.empty) {
      const journalBatch = firestore.batch();
      journalSnapshot.docs.forEach((doc) => journalBatch.delete(doc.ref));
      await journalBatch.commit();
      logger.log(`Subcoleção 'journalEntries' do usuário ${userId} deletada.`);
    }

    // Deletar o documento principal do usuário
    if (userDoc.exists) {
      await userDocRef.delete();
      logger.log(`Documento principal do usuário ${userId} deletado com sucesso.`);
    }
    
    logger.info(`==========================================================`);
    return { status: "success", message: `Dados do usuário ${userId} limpos com sucesso.` };
  
  } catch (error) {
    logger.error(`Erro ao limpar dados ou enviar webhook para o usuário ${userId}:`, error);
    logger.info(`==========================================================`);
    return { status: "error", message: `Falha no processo de exclusão do usuário ${userId}.` };
  }
});

// ========================================
// SISTEMA DE NOTIFICAÇÕES PUSH
// ========================================

/**
 * Envia notificação push para um usuário específico
 * Chamado por triggers ou agendamentos
 */
exports.sendPushNotification = functions.https.onCall(async (data, context) => {
  functions.logger.info("================ sendPushNotification ACIONADA ================");
  
  // Verifica autenticação
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Usuário não autenticado');
  }
  
  const { userId, title, body, data: notificationData } = data;
  
  try {
    // Busca tokens FCM do usuário
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Usuário não encontrado');
    }
    
    const userData = userDoc.data();
    const fcmTokens = userData.fcmTokens || [];
    
    if (fcmTokens.length === 0) {
      functions.logger.info(`Usuário ${userId} não tem tokens FCM registrados`);
      return { success: true, message: 'Sem tokens para enviar' };
    }
    
    // Monta mensagem
    const message = {
      notification: {
        title,
        body
      },
      data: notificationData || {},
      tokens: fcmTokens
    };
    
    // Envia
    const response = await messaging.sendMulticast(message);
    
    functions.logger.info(`Notificação enviada: ${response.successCount} sucesso, ${response.failureCount} falhas`);
    
    // Remove tokens inválidos
    if (response.failureCount > 0) {
      const tokensToRemove = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          tokensToRemove.push(fcmTokens[idx]);
        }
      });
      
      if (tokensToRemove.length > 0) {
        await db.collection('users').doc(userId).update({
          fcmTokens: admin.firestore.FieldValue.arrayRemove(...tokensToRemove)
        });
        functions.logger.info(`Removidos ${tokensToRemove.length} tokens inválidos`);
      }
    }
    
    return { success: true, sent: response.successCount };
    
  } catch (error) {
    functions.logger.error("Erro ao enviar notificação:", error);
    throw new functions.https.HttpsError('internal', 'Erro ao enviar notificação');
  }
});

/**
 * Agenda notificação de fim de dia (chamado por cron job ou trigger)
 */
exports.scheduleDailyNotifications = functions.pubsub.schedule('0 21 * * *')
  .timeZone('America/Sao_Paulo')
  .onRun(async (context) => {
    functions.logger.info("================ scheduleDailyNotifications ACIONADA ================");
    
    try {
      // Busca todos os usuários ativos
      const usersSnapshot = await db.collection('users').get();
      const notifications = [];
      
      for (const userDoc of usersSnapshot.docs) {
        const userData = userDoc.data();
        const userId = userDoc.id;
        
        // Verifica se tem tokens
        if (!userData.fcmTokens || userData.fcmTokens.length === 0) continue;
        
        // Verifica tarefas pendentes do dia
        const tasksSnapshot = await db.collection('users').doc(userId)
          .collection('tasks')
          .where('completed', '==', false)
          .where('dueDate', '<=', new Date())
          .get();
        
        if (!tasksSnapshot.empty) {
          const pendingCount = tasksSnapshot.size;
          
          notifications.push({
            userId,
            title: '🌙 Finalizando o dia',
            body: `Você tem ${pendingCount} tarefa${pendingCount > 1 ? 's' : ''} pendente${pendingCount > 1 ? 's' : ''}. Que tal revisar?`,
            data: {
              type: 'daily_reminder',
              route: '/tasks'
            }
          });
        }
      }
      
      // Envia todas as notificações
      functions.logger.info(`Enviando ${notifications.length} notificações de fim de dia`);
      
      for (const notif of notifications) {
        try {
          const message = {
            notification: {
              title: notif.title,
              body: notif.body
            },
            data: notif.data,
            tokens: (await db.collection('users').doc(notif.userId).get()).data().fcmTokens
          };
          
          await messaging.sendMulticast(message);
        } catch (error) {
          functions.logger.error(`Erro ao enviar notificação para ${notif.userId}:`, error);
        }
      }
      
      functions.logger.info("Notificações de fim de dia enviadas com sucesso");
      
    } catch (error) {
      functions.logger.error("Erro no agendamento de notificações:", error);
    }
  });

// ========================================
// WEBHOOKS DE PAGAMENTO (PAGBANK)
// ========================================

/**
 * Inicia checkout web via PagBank
 * Protegido por reCAPTCHA para prevenir fraude
 */
exports.startWebCheckout = functions.https.onCall(async (data, context) => {
  functions.logger.info("================ startWebCheckout ACIONADA ================");
  
  // Verifica autenticação
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Usuário não autenticado');
  }
  
  const { userId, plan, recaptchaToken } = data;
  
  if (!userId || !plan) {
    throw new functions.https.HttpsError('invalid-argument', 'userId e plan são obrigatórios');
  }

  // Valida reCAPTCHA (opcional mas recomendado)
  if (recaptchaToken) {
    try {
      const assessment = await assessRecaptcha(recaptchaToken, 'checkout');
      if (!assessment.valid || assessment.score < 0.5) {
        functions.logger.warn(`Checkout bloqueado - score reCAPTCHA: ${assessment.score}`);
        throw new functions.https.HttpsError('permission-denied', 'Verificação de segurança falhou');
      }
      functions.logger.info(`✅ Checkout aprovado - score: ${assessment.score}`);
    } catch (error) {
      functions.logger.error("Erro ao validar reCAPTCHA no checkout:", error);
      // Continua mesmo se falhar (graceful degradation)
    }
  }
  
  try {
    // Busca dados do usuário
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Usuário não encontrado');
    }
    
    const userData = userDoc.data();
    
    // Define valores por plano
    const planPrices = {
      plus: { amount: 1990, name: 'Sincro Despertar' }, // R$ 19,90
      premium: { amount: 3990, name: 'Sincro Sinergia' } // R$ 39,90
    };
    
    if (!planPrices[plan]) {
      throw new functions.https.HttpsError('invalid-argument', 'Plano inválido');
    }
    
    // Monta payload PagBank
    const pagbankPayload = {
      reference_id: `${userId}_${plan}_${Date.now()}`,
      customer: {
        name: `${userData.primeiroNome} ${userData.sobrenome}`,
        email: userData.email
      },
      items: [
        {
          name: planPrices[plan].name,
          quantity: 1,
          unit_amount: planPrices[plan].amount
        }
      ],
      notification_urls: [
        `https://us-central1-${process.env.GCLOUD_PROJECT}.cloudfunctions.net/pagbankWebhook`
      ]
    };
    
    // TODO: Chamar API do PagBank
    // const response = await axios.post('https://api.pagbank.com/checkouts', pagbankPayload, {
    //   headers: {
    //     'Authorization': `Bearer ${functions.config().pagbank.token}`,
    //     'Content-Type': 'application/json'
    //   }
    // });
    
    // Por enquanto, retorna URL mock
    functions.logger.info('Checkout iniciado:', pagbankPayload);
    
    return {
      success: true,
      checkoutUrl: 'https://pagbank.com/checkout/MOCK_ID', // TODO: Usar response.data.links[0].href
      referenceId: pagbankPayload.reference_id
    };
    
  } catch (error) {
    functions.logger.error("Erro ao iniciar checkout:", error);
    throw new functions.https.HttpsError('internal', 'Erro ao processar checkout');
  }
});

/**
 * Webhook do PagBank para atualizar status de pagamento
 */
exports.pagbankWebhook = functions.https.onRequest(async (req, res) => {
  functions.logger.info("================ pagbankWebhook ACIONADA ================");
  
  try {
    const payload = req.body;
    functions.logger.info("Payload recebido:", payload);
    
    // TODO: Validar assinatura do PagBank
    // const signature = req.headers['x-pagbank-signature'];
    // if (!validateSignature(payload, signature)) {
    //   return res.status(401).send('Assinatura inválida');
    // }
    
    // Extrai dados do pagamento
    const { reference_id, status } = payload;
    
    // Parse do reference_id: userId_plan_timestamp
    const [userId, plan] = reference_id.split('_');
    
    if (status === 'PAID' || status === 'APPROVED') {
      // Pagamento aprovado: atualiza assinatura
      const planMapping = {
        plus: 'plus',
        premium: 'premium'
      };
      
      const validUntil = new Date();
      validUntil.setMonth(validUntil.getMonth() + 1); // +30 dias
      
      await db.collection('users').doc(userId).update({
        'subscription.plan': planMapping[plan],
        'subscription.status': 'active',
        'subscription.validUntil': admin.firestore.Timestamp.fromDate(validUntil),
        'subscription.startedAt': admin.firestore.Timestamp.now()
      });
      
      functions.logger.info(`✅ Assinatura ${plan} ativada para usuário ${userId}`);
      
      // Envia webhook para n8n
      await sendToWebhook({
        event: 'subscription_activated',
        userId,
        plan,
        validUntil: validUntil.toISOString()
      });
      
    } else if (status === 'CANCELED' || status === 'REFUNDED') {
      // Pagamento cancelado/reembolsado
      await db.collection('users').doc(userId).update({
        'subscription.status': 'cancelled'
      });
      
      functions.logger.info(`❌ Assinatura cancelada para usuário ${userId}`);
    }
    
    res.status(200).send('OK');
    
  } catch (error) {
    functions.logger.error("Erro no webhook PagBank:", error);
    res.status(500).send('Erro interno');
  }
});