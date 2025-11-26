const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");

// Inicializa o SDK Admin
admin.initializeApp();

// URL do seu webhook
const N8N_WEBHOOK_URL = "https://n8n.studiomlk.com.br/webhook/sincroapp";

/**
 * Fun+∫+˙o auxiliar para enviar dados ao webhook do n8n.
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

/**
 * Acionado quando um novo documento de usu+Ìrio +Æ criado no Firestore.
 * Envia um evento 'user_created' para o n8n.
 */
exports.onNewUserDocumentCreate = functions.firestore.document("users/{userId}").onCreate(async (snapshot, context) => {
  functions.logger.info("================ onNewUserDocumentCreate ACIONADA ================");
  const userData = snapshot.data();
  const userId = context.params.userId;
  functions.logger.info("Novo documento de usu+Ìrio criado:", { uid: userId, data: userData });
  
  const payload = {
    event: "user_created",
    email: userData.email,
    name: `${userData.primeiroNome || ''} ${userData.sobrenome || ''}`.trim(),
    plan: userData.plano || "gratuito",
    userId: userId,
  };
  
  await sendToWebhook(payload);
  
  functions.logger.info("Fun+∫+˙o onNewUserDocumentCreate conclu+°da.");
  functions.logger.info("================================================================");
  return null;
});

/**
 * Acionado quando um documento de usu+Ìrio +Æ atualizado no Firestore.
 * Se o plano mudou para 'premium', envia um evento 'plan_upgraded'.
 */
exports.onUserUpdate = functions.firestore.document("users/{userId}").onUpdate(async (change, context) => {
  functions.logger.info("================ onUserUpdate ACIONADA ================");
  const beforeData = change.before.data();
  const afterData = change.after.data();
  const userId = context.params.userId;
  functions.logger.info(`Documento do usu+Ìrio ${userId} foi atualizado.`);

  // Verifica se o plano foi atualizado para premium
  if (beforeData.plano !== "premium" && afterData.plano === "premium") {
    functions.logger.info(`Usu+Ìrio ${userId} fez upgrade para o plano Premium.`);
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
 * Acionado quando um usu+Ìrio +Æ exclu+°do do Firebase Authentication.
 * 1. Envia um webhook 'user_deleted' para o n8n.
 * 2. Limpa todos os dados associados a esse usu+Ìrio no Firestore.
 */
exports.onUserDeleted = functions.auth.user().onDelete(async (user) => {
  const userId = user.uid;
  const userEmail = user.email; // O e-mail vem do objeto 'user' do Auth
  const logger = functions.logger;
  logger.info(`================ onUserDeleted ACIONADA =================`);
  logger.info(`Usu+Ìrio a ser deletado: ${userId} (${userEmail})`);

  const firestore = admin.firestore();
  const userDocRef = firestore.collection("users").doc(userId);

  try {
    // --- PASSO 1: Buscar dados do usu+Ìrio ANTES de deletar ---
    const userDoc = await userDocRef.get();
    let userName = '';
    if (userDoc.exists) {
      const userData = userDoc.data();
      userName = `${userData.primeiroNome || ''} ${userData.sobrenome || ''}`.trim();
      logger.info(`Dados do usu+Ìrio encontrados para o webhook: ${userName}`);
    } else {
      logger.warn(`Documento ${userId} n+˙o encontrado no Firestore, mas a conta de autentica+∫+˙o foi exclu+°da.`);
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

    // --- PASSO 3: Limpeza dos dados do Firestore (l+¶gica original) ---
    logger.info(`Iniciando limpeza de dados do Firestore para o usu+Ìrio: ${userId}`);
    
    // Deletar subcole+∫+˙o 'tasks'
    const tasksRef = userDocRef.collection("tasks");
    const tasksSnapshot = await tasksRef.get();
    if (!tasksSnapshot.empty) {
      const batch = firestore.batch();
      tasksSnapshot.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
      logger.log(`Subcole+∫+˙o 'tasks' do usu+Ìrio ${userId} deletada.`);
    }

    // Deletar subcole+∫+˙o 'journalEntries'
    const journalRef = userDocRef.collection("journalEntries");
    const journalSnapshot = await journalRef.get();
    if (!journalSnapshot.empty) {
      const journalBatch = firestore.batch();
      journalSnapshot.docs.forEach((doc) => journalBatch.delete(doc.ref));
      await journalBatch.commit();
      logger.log(`Subcole+∫+˙o 'journalEntries' do usu+Ìrio ${userId} deletada.`);
    }

    // Deletar o documento principal do usu+Ìrio
    if (userDoc.exists) {
      await userDocRef.delete();
      logger.log(`Documento principal do usu+Ìrio ${userId} deletado com sucesso.`);
    }
    
    logger.info(`==========================================================`);
    return { status: "success", message: `Dados do usu+Ìrio ${userId} limpos com sucesso.` };
  
  } catch (error) {
    logger.error(`Erro ao limpar dados ou enviar webhook para o usu+Ìrio ${userId}:`, error);
    logger.info(`==========================================================`);
    return { status: "error", message: `Falha no processo de exclus+˙o do usu+Ìrio ${userId}.` };
  }
});

// ========================================
// WEBHOOKS DE PAGAMENTO (PAGBANK)
// ========================================

// Token PagBank (ambiente de teste)
const PAGBANK_TOKEN = 'eafff115-5393-4566-b470-70e3a3016e23448c98f54df88f35255b8ff344373ddc8ec3-275a-4d80-b1a0-02dc946cc97c';
const PAGBANK_API_URL = 'https://sandbox.api.pagbank.com';

/**
 * Inicia checkout web via PagBank
 */
exports.startWebCheckout = functions.https.onCall(async (data, context) => {
    functions.logger.info('================ startWebCheckout ACIONADA ================');

    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Usu√°rio n√£o autenticado');
    }

    const { userId, plan, recaptchaToken, billingCycle = 'monthly' } = data;

    if (!userId || !plan) {
        throw new functions.https.HttpsError('invalid-argument', 'userId e plan s√£o obrigat√≥rios');
    }

    if (recaptchaToken) {
        try {
            const assessment = await assessRecaptcha(recaptchaToken, 'checkout');
            if (!assessment.valid || assessment.score < 0.5) {
                functions.logger.warn(`Checkout bloqueado - score reCAPTCHA: ${assessment.score}`);
                throw new functions.https.HttpsError('permission-denied', 'Verifica√ß√£o de seguran√ßa falhou');
            }
            functions.logger.info(`‚úÖ Checkout aprovado - score: ${assessment.score}`);
        } catch (error) {
            functions.logger.error('Erro ao validar reCAPTCHA no checkout:', error);
        }
    }

    try {
        const userDoc = await db.collection('users').doc(userId).get();
        if (!userDoc.exists) {
            throw new functions.https.HttpsError('not-found', 'Usu√°rio n√£o encontrado');
        }

        const userData = userDoc.data();

        const planPrices = {
            plus: {
                monthly: 1990,
                annual: 19104,
                name: 'Sincro Desperta'
            },
            premium: {
                monthly: 3990,
                annual: 38304,
                name: 'Sincro Sinergia'
            }
        };

        if (!planPrices[plan]) {
            throw new functions.https.HttpsError('invalid-argument', 'Plano inv√°lido');
        }

        const amount = billingCycle === 'annual' ? planPrices[plan].annual : planPrices[plan].monthly;
        const description = `${planPrices[plan].name} (${billingCycle === 'annual' ? 'Anual' : 'Mensal'})`;
        const referenceId = `${userId}_${plan}_${billingCycle}_${Date.now()}`;

        const pagbankPayload = {
            reference_id: referenceId,
            customer_modifiable: false,
            items: [
                {
                    name: description,
                    quantity: 1,
                    unit_amount: amount
                }
            ],
            notification_urls: [
                `https://us-central1-${process.env.GCLOUD_PROJECT}.cloudfunctions.net/pagbankWebhook`
            ],
            payment_notification_urls: [
                `https://us-central1-${process.env.GCLOUD_PROJECT}.cloudfunctions.net/pagbankWebhook`
            ]
        };

        functions.logger.info('Criando checkout PagBank:', { referenceId, amount, billingCycle });

        const response = await axios.post(
            `${PAGBANK_API_URL}/checkouts`,
            pagbankPayload,
            {
                headers: {
                    'Authorization': `Bearer ${PAGBANK_TOKEN}`,
                    'Content-Type': 'application/json',
                    'Accept': 'application/json'
                }
            }
        );

        functions.logger.info('Resposta PagBank:', response.data);

        const payLink = response.data.links.find(link => link.rel === 'PAY');

        if (!payLink) {
            throw new Error('URL de pagamento n√£o encontrada na resposta do PagBank');
        }

        return {
            success: true,
            checkoutUrl: payLink.href,
            checkoutId: response.data.id,
            referenceId: referenceId
        };

    } catch (error) {
        functions.logger.error('Erro ao iniciar checkout:', error.response?.data || error.message);
        throw new functions.https.HttpsError('internal', `Erro ao processar checkout: ${error.message}`);
    }
});

/**
 * Webhook do PagBank
 */
exports.pagbankWebhook = functions.https.onRequest(async (req, res) => {
    functions.logger.info('================ pagbankWebhook ACIONADA ================');

    try {
        const payload = req.body;
        functions.logger.info('Payload recebido:', JSON.stringify(payload, null, 2));

        const { reference_id, status, charges } = payload;

        if (!reference_id) {
            functions.logger.error('reference_id n√£o encontrado no payload');
            return res.status(400).send('reference_id obrigat√≥rio');
        }

        const parts = reference_id.split('_');
        const userId = parts[0];
        const plan = parts[1];
        const billingCycle = parts[2] || 'monthly';

        functions.logger.info(`Processando webhook para userId: ${userId}, plan: ${plan}, cycle: ${billingCycle}, status: ${status}`);

        if (status === 'PAID' || status === 'APPROVED' || (charges && charges[0]?.status === 'PAID')) {
            const planMapping = {
                plus: 'plus',
                premium: 'premium'
            };

            const validUntil = new Date();

            if (billingCycle === 'annual') {
                validUntil.setFullYear(validUntil.getFullYear() + 1);
            } else {
                validUntil.setMonth(validUntil.getMonth() + 1);
            }

            await db.collection('users').doc(userId).update({
                'subscription.plan': planMapping[plan],
                'subscription.status': 'active',
                'subscription.billingCycle': billingCycle,
                'subscription.validUntil': admin.firestore.Timestamp.fromDate(validUntil),
                'subscription.startedAt': admin.firestore.Timestamp.now()
            });

            functions.logger.info(`‚úÖ Assinatura ${plan} (${billingCycle}) ativada para usu√°rio ${userId} at√© ${validUntil.toISOString()}`);

            await sendToWebhook({
                event: 'subscription_activated',
                userId,
                plan,
                billingCycle,
                validUntil: validUntil.toISOString()
            });

        } else if (status === 'CANCELED' || status === 'REFUNDED') {
            await db.collection('users').doc(userId).update({
                'subscription.status': 'cancelled'
            });

            functions.logger.info(`‚ùå Assinatura cancelada para usu√°rio ${userId}`);

            await sendToWebhook({
                event: 'subscription_cancelled',
                userId,
                plan,
                reason: status
            });
        }

        res.status(200).send('OK');

    } catch (error) {
        functions.logger.error('Erro no webhook PagBank:', error);
        res.status(500).send('Erro interno');
    }
});
