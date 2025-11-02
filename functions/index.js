const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");

// Inicializa o SDK Admin
admin.initializeApp();

// URL do seu webhook
const N8N_WEBHOOK_URL = "https://n8n.studiomlk.com.br/webhook/sincroapp";

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