
require('dotenv').config();
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { FieldValue } = require("firebase-admin/firestore");
const axios = require("axios");
const { Client } = require("@notionhq/client");
// Initialize Stripe with your Secret Key
const stripe = require("stripe")(process.env.STRIPE_SECRET_KEY);

admin.initializeApp();
const db = admin.firestore();

// Webhook URLs (n8n)
const N8N_WEBHOOK_URL = "https://n8n.webhook.sincroapp.com.br/webhook/stripe-events";
const FEEDBACK_WEBHOOK_URL = "https://n8n.studiomlk.com.br/webhook/sincroapp-feedback";
const TRANSACTION_WEBHOOK_URL = "https://n8n.studiomlk.com.br/webhook/sincroapp";

// Notion Config
const notion = new Client({ auth: process.env.NOTION_API_KEY });
const NOTION_DATABASE_ID = process.env.NOTION_FAQ_DATABASE_ID;

// --- Cloud Function: Get FAQ from Notion ---
exports.getFaq = functions.https.onRequest(async (req, res) => {
    console.log("DEBUG: Function started");
    console.log("DEBUG: API Key exists?", !!process.env.NOTION_API_KEY);
    console.log("DEBUG: DB ID exists?", !!process.env.NOTION_FAQ_DATABASE_ID);
    // Enable CORS
    res.set('Access-Control-Allow-Origin', '*');
    if (req.method === 'OPTIONS') {
        res.set('Access-Control-Allow-Methods', 'GET');
        res.set('Access-Control-Allow-Headers', 'Content-Type');
        res.status(204).send('');
        return;
    }

    try {
        // 1. Query Database to get Questions (Title + Category)
        const response = await notion.databases.query({
            database_id: NOTION_DATABASE_ID,
            filter: {
                property: "Publicado", // Checkbox property
                checkbox: {
                    equals: true,
                },
            },
        });

        const items = [];

        // 2. Iterate results and fetch Page Content (The Answer)
        for (const page of response.results) {
            const questionTitle = page.properties.Pergunta?.title[0]?.plain_text || "Sem título";
            // Reading from the new "Tópico" Select property
            const category = page.properties['Tópico']?.select?.name || "Geral";

            // Fetch blocks (content) of the page
            const blocks = await notion.blocks.children.list({
                block_id: page.id,
            });

            // Convert blocks to simple HTML (simplified for this MVP)
            let htmlContent = "";
            for (const block of blocks.results) {
                if (block.type === 'paragraph') {
                    const text = block.paragraph.rich_text.map(t => t.plain_text).join("");
                    if (text) htmlContent += `<p>${text}</p>`;
                } else if (block.type === 'heading_1') {
                    htmlContent += `<h3>${block.heading_1.rich_text.map(t => t.plain_text).join("")}</h3>`;
                } else if (block.type === 'heading_2') {
                    htmlContent += `<h4>${block.heading_2.rich_text.map(t => t.plain_text).join("")}</h4>`;
                } else if (block.type === 'bulleted_list_item') {
                    htmlContent += `<ul><li>${block.bulleted_list_item.rich_text.map(t => t.plain_text).join("")}</li></ul>`;
                }
                // Add more block types as needed
            }

            items.push({
                id: page.id,
                question: questionTitle,
                category: category,
                answerHtml: htmlContent
            });
        }

        res.status(200).json({ faq: items });

    } catch (error) {
        functions.logger.error("Notion API Error", error);
        res.status(500).json({ error: "Failed to fetch FAQ", details: error.message });
    }
});

/**
 * Função auxiliar para enviar dados ao webhook do n8n.
 */
const sendToWebhook = async (payload, targetUrl = TRANSACTION_WEBHOOK_URL) => {
    try {
        functions.logger.info(`Tentando enviar dados para o n8n(${targetUrl}): `, payload);
        await axios.post(targetUrl, payload);
        functions.logger.info("Webhook enviado com sucesso para n8n.");
    } catch (error) {
        functions.logger.error("ERRO AO ENVIAR WEBHOOK:", { errorMessage: error.message });
    }
};

// ... (existing code) ...

/**
 * Envia Feedback do usuário para o n8n
 */
exports.submitFeedback = functions.https.onCall(async (data, context) => {
    // Autenticação opcional, mas recomendada se quisermos garantir que é um usuário
    // if (!context.auth) ...

    try {
        const { type, description, app_version: appVersion, device_info: deviceInfo, user_id: userId, user_email: userEmail, attachment_url: attachmentUrl } = data;

        // 1. Fetch User Name from Firestore
        let userName = 'Usuário';
        if (userId) {
            try {
                const userDoc = await admin.firestore().collection('users').doc(userId).get();
                if (userDoc.exists) {
                    const userData = userDoc.data();
                    userName = `${userData.primeiroNome || ''} ${userData.sobrenome || ''} `.trim();
                }
            } catch (e) {
                console.warn('Erro ao buscar nome do usuário para feedback:', e);
            }
        }

        // Note: Passing the specific FEEDBACK_WEBHOOK_URL here
        await sendToWebhook({
            event: 'user_feedback',
            type: type, // 'Bug' ou 'Idea'
            description: description,
            app_version: appVersion,
            device_info: deviceInfo,
            user_id: userId || (context.auth ? context.auth.uid : 'anonymous'),
            user_email: userEmail || (context.auth ? context.auth.token.email : 'anonymous'),
            name: userName, // Added Name
            image_url: attachmentUrl || null, // Added Image URL
            timestamp: new Date().toISOString()
        }, FEEDBACK_WEBHOOK_URL);

        return { success: true };
    } catch (error) {
        console.error("Erro ao enviar feedback:", error);
        throw new functions.https.HttpsError('internal', 'Erro ao processar feedback.');
    }
});

/**
 * Cria uma Assinatura no Stripe
 */
exports.createSubscription = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "A função deve ser chamada enquanto autenticado."
        );
    }

    const { priceId, customerId } = data;

    if (!priceId) {
        throw new functions.https.HttpsError("invalid-argument", "A função deve ser chamada com um priceId.");
    }

    try {
        let customer = customerId;

        // Se não houver ID de cliente, procure ou crie um
        if (!customer) {
            const userSnapshot = await admin.firestore().collection("users").doc(context.auth.uid).get();
            const userData = userSnapshot.data();

            if (userData && userData.stripeId) {
                customer = userData.stripeId;
            } else {
                // Criar novo cliente Stripe
                const newCustomer = await stripe.customers.create({
                    email: context.auth.token.email,
                    metadata: {
                        firebaseUID: context.auth.uid
                    }
                });
                customer = newCustomer.id;

                // Salvar Stripe ID no Firestore
                await admin.firestore().collection("users").doc(context.auth.uid).update({
                    stripeId: customer
                });
            }
        }

        // Criar a assinatura
        const subscription = await stripe.subscriptions.create({
            customer: customer,
            items: [{
                price: priceId,
            }],
            payment_behavior: 'default_incomplete',
            payment_settings: { save_default_payment_method: 'on_subscription' },
            expand: ['latest_invoice.payment_intent'],
        });

        console.log("Subscription created:", JSON.stringify(subscription, null, 2));

        const invoice = subscription.latest_invoice;
        let clientSecret = null;

        if (invoice && invoice.payment_intent) {
            clientSecret = invoice.payment_intent.client_secret;
        } else {
            console.warn("Payment Intent not found on latest_invoice:", JSON.stringify(invoice, null, 2));
        }

        const ephemeralKey = await stripe.ephemeralKeys.create(
            { customer: customer },
            { apiVersion: "2023-10-16" }
        );

        return {
            subscriptionId: subscription.id,
            clientSecret: clientSecret,
            ephemeralKey: ephemeralKey.secret,
            customer: customer,
        };
    } catch (error) {
        console.error("Erro ao criar assinatura:", error);
        throw new functions.https.HttpsError("internal", error.message);
    }
});

/**
 * Webhook para lidar com eventos do Stripe
 */
exports.stripeWebhook = functions.https.onRequest(async (req, res) => {
    const sig = req.headers["stripe-signature"];
    // TODO: Substitua pelo seu Segredo de Webhook real do Dashboard do Stripe
    const endpointSecret = "whsec_...";

    let event;

    try {
        event = stripe.webhooks.constructEvent(req.rawBody, sig, endpointSecret);
    } catch (err) {
        console.error(`Falha na verificação da assinatura do webhook.`, err.message);
        return res.status(400).send(`Erro Webhook: ${err.message} `);
    }

    const dataObject = event.data.object;

    try {
        // Manipular o evento
        switch (event.type) {
            case "checkout.session.completed": {
                const session = dataObject;
                const userId = session.client_reference_id;
                const customerId = session.customer;

                if (userId) {
                    console.log(`Checkout completo para usuário ${userId}. Atualizando stripeId: ${customerId}`);
                    await admin.firestore().collection('users').doc(userId).update({
                        stripeId: customerId
                    });
                } else {
                    console.warn(`Checkout session completed sem client_reference_id. Customer: ${customerId}`);
                }
                break;
            }

            case "invoice.payment_succeeded": {
                const customerId = dataObject.customer;
                const amount = dataObject.amount_paid / 100; // Valor em reais
                const currency = dataObject.currency;

                // Buscar usuário no Firestore pelo stripeId
                const usersRef = admin.firestore().collection('users');
                const snapshot = await usersRef.where('stripeId', '==', customerId).limit(1).get();

                if (!snapshot.empty) {
                    const userDoc = snapshot.docs[0];
                    const userData = userDoc.data();
                    const userId = userDoc.id;

                    // Atualizar status no Firestore
                    // Nota: A lógica exata de qual plano é depende do Price ID, 
                    // mas aqui vamos apenas garantir que está ativo.
                    // Idealmente, mapearíamos Price ID -> Nome do Plano.

                    await userDoc.ref.update({
                        'subscription.status': 'active',
                        'subscription.lastPayment': FieldValue.serverTimestamp()
                    });

                    // Enviar notificação para n8n
                    await sendToWebhook({
                        event: 'subscription_activated',
                        email: userData.email,
                        name: `${userData.primeiroNome || ''} ${userData.sobrenome || ''} `.trim(),
                        userId: userId,
                        amount: amount,
                        currency: currency,
                        stripeCustomerId: customerId
                    });
                }
                break;
            }

            case "customer.subscription.deleted": {
                const customerId = dataObject.customer;

                const usersRef = admin.firestore().collection('users');
                const snapshot = await usersRef.where('stripeId', '==', customerId).limit(1).get();

                if (!snapshot.empty) {
                    const userDoc = snapshot.docs[0];
                    const userData = userDoc.data();
                    const userId = userDoc.id;

                    await userDoc.ref.update({
                        'subscription.status': 'cancelled'
                    });

                    await sendToWebhook({
                        event: 'subscription_cancelled',
                        email: userData.email,
                        name: `${userData.primeiroNome || ''} ${userData.sobrenome || ''} `.trim(),
                        userId: userId
                    });
                }
                break;
            }

            case "customer.subscription.updated": {
                const subscription = dataObject;
                const customerId = subscription.customer;
                const status = subscription.status;
                const priceId = subscription.items.data[0].price.id;

                const usersRef = admin.firestore().collection('users');
                const snapshot = await usersRef.where('stripeId', '==', customerId).limit(1).get();

                if (!snapshot.empty) {
                    const userDoc = snapshot.docs[0];
                    const userData = userDoc.data();
                    const userId = userDoc.id;

                    await userDoc.ref.update({
                        'subscription.status': status,
                        'subscription.priceId': priceId,
                        'subscription.updatedAt': FieldValue.serverTimestamp()
                    });

                    await sendToWebhook({
                        event: 'subscription_updated',
                        email: userData.email,
                        name: `${userData.primeiroNome || ''} ${userData.sobrenome || ''} `.trim(),
                        userId: userId,
                        status: status,
                        priceId: priceId
                    });
                }
                break;
            }

            case "invoice.payment_failed": {
                const customerId = dataObject.customer;

                const usersRef = admin.firestore().collection('users');
                const snapshot = await usersRef.where('stripeId', '==', customerId).limit(1).get();

                if (!snapshot.empty) {
                    const userDoc = snapshot.docs[0];
                    const userData = userDoc.data();

                    await sendToWebhook({
                        event: 'payment_failed',
                        email: userData.email,
                        name: `${userData.primeiroNome || ''} ${userData.sobrenome || ''} `.trim(),
                        userId: userDoc.id
                    });
                }
                break;
            }

            default:
                console.log(`Tipo de evento não tratado: ${event.type} `);
        }
    } catch (error) {
        console.error("Erro ao processar webhook:", error);
    }

    res.json({ received: true });
});

/**
 * Acionado quando um novo documento de usuário é criado no Firestore.
 * Envia um evento 'user_created' para o n8n.
 */
exports.onNewUserDocumentCreate = functions.firestore.document("users/{userId}").onCreate(async (snapshot, context) => {
    functions.logger.info("================ onNewUserDocumentCreate ACIONADA ================");
    const userData = snapshot.data();
    const userId = context.params.userId;

    const payload = {
        event: "user_created",
        email: userData.email,
        name: `${userData.primeiroNome || ''} ${userData.sobrenome || ''} `.trim(),
        plan: userData.plano || "gratuito",
        userId: userId,
    };

    await sendToWebhook(payload);
    return null;
});

/**
 * Acionado quando um novo usuário é criado no Firebase Auth.
 * Garante que o documento do usuário exista no Firestore.
 * Isso é útil para testes no Emulador (onde a UI cria Auth mas não Doc)
 * e como fallback de segurança.
 */
exports.onAuthUserCreate = functions.auth.user().onCreate(async (user) => {
    functions.logger.info(`================ onAuthUserCreate ACIONADA: ${user.email} ================= `);

    const db = admin.firestore();
    const userRef = db.collection('users').doc(user.uid);

    try {
        const doc = await userRef.get();
        if (!doc.exists) {
            functions.logger.info("Documento Firestore não encontrado. Criando documento padrão...");

            // Cria o documento com dados básicos do Auth
            const userData = {
                email: user.email,
                uid: user.uid,
                primeiroNome: user.displayName ? user.displayName.split(' ')[0] : 'Novo',
                sobrenome: user.displayName ? user.displayName.split(' ').slice(1).join(' ') : 'Usuário',
                createdAt: FieldValue.serverTimestamp(),
                plano: 'gratuito',
                // Adicione outros campos padrão aqui se necessário
            };

            await userRef.set(userData);
            functions.logger.info("Documento criado com sucesso. Isso deve acionar onNewUserDocumentCreate.");
        } else {
            functions.logger.info("Documento Firestore já existe. Nenhuma ação necessária.");
        }
    } catch (error) {
        functions.logger.error("Erro ao garantir documento do usuário:", error);
    }
});

/**
 * Acionado quando um usuário é excluído do Firebase Authentication.
 * 1. Envia um webhook 'user_deleted' para o n8n.
 * 2. Limpa todos os dados associados a esse usuário no Firestore.
 */
exports.onUserDeleted = functions.auth.user().onDelete(async (user) => {
    const userId = user.uid;
    const userEmail = user.email;
    const logger = functions.logger;
    logger.info(`================ onUserDeleted ACIONADA ================= `);

    const firestore = admin.firestore();
    const userDocRef = firestore.collection("users").doc(userId);

    try {
        // --- PASSO 1: Buscar dados do usuário ANTES de deletar ---
        const userDoc = await userDocRef.get();
        let userName = '';
        if (userDoc.exists) {
            const userData = userDoc.data();
            userName = `${userData.primeiroNome || ''} ${userData.sobrenome || ''} `.trim();
        }

        // --- PASSO 2: Enviar o webhook de conta deletada ---
        const payload = {
            event: "user_deleted",
            email: userEmail,
            name: userName,
            userId: userId,
        };
        await sendToWebhook(payload);

        // --- PASSO 3: Limpeza dos dados do Firestore ---

        // Deletar subcoleção 'tasks'
        const tasksRef = userDocRef.collection("tasks");
        const tasksSnapshot = await tasksRef.get();
        if (!tasksSnapshot.empty) {
            const batch = firestore.batch();
            tasksSnapshot.docs.forEach((doc) => batch.delete(doc.ref));
            await batch.commit();
        }

        // Deletar subcoleção 'journalEntries'
        const journalRef = userDocRef.collection("journalEntries");
        const journalSnapshot = await journalRef.get();
        if (!journalSnapshot.empty) {
            const journalBatch = firestore.batch();
            journalSnapshot.docs.forEach((doc) => journalBatch.delete(doc.ref));
            await journalBatch.commit();
        }

        // Deletar o documento principal do usuário
        if (userDoc.exists) {
            await userDocRef.delete();
        }

        return { status: "success", message: `Dados do usuário ${userId} limpos com sucesso.` };

    } catch (error) {
        logger.error(`Erro ao limpar dados ou enviar webhook para o usuário ${userId}: `, error);
        return { status: "error", message: `Falha no processo de exclusão do usuário ${userId}.` };
    }
});

/**
 * Solicita redefinição de senha personalizada via n8n
 */
/**
 * Solicita redefinição de senha personalizada via n8n (Gera Token Customizado)
 */
exports.requestPasswordReset = functions.https.onCall(async (data, context) => {
    const { email } = data;
    const crypto = require('crypto');

    if (!email) {
        throw new functions.https.HttpsError('invalid-argument', 'O e-mail é obrigatório.');
    }

    try {
        functions.logger.info(`Iniciando requestPasswordReset para: ${email} `);

        // 1. Verificar se o usuário existe
        let userRecord;
        try {
            userRecord = await admin.auth().getUserByEmail(email);
        } catch (e) {
            if (e.code === 'auth/user-not-found') {
                functions.logger.warn(`Email não encontrado no Auth: ${email}. Retornando sucesso.`);
                // Retorna sucesso por segurança (user enumeration)
                return { success: true };
            }
            functions.logger.error(`Erro ao buscar usuário no Auth: ${e.message} `);
            throw e;
        }

        // 2. Gerar Token Seguro
        const token = crypto.randomBytes(32).toString('hex');
        const expiresAt = Timestamp.fromMillis(Date.now() + 3600000); // 1 hora de validade

        // 3. Salvar Token no Firestore
        try {
            await admin.firestore().collection('password_resets').add({
                email: email,
                token: token,
                expiresAt: expiresAt,
                used: false,
                createdAt: FieldValue.serverTimestamp()
            });
            functions.logger.info(`Token de reset salvo no Firestore.`);
        } catch (e) {
            functions.logger.error(`Erro ao salvar token no Firestore: ${e.message} `, e);
            throw new functions.https.HttpsError('internal', 'Falha ao gerar token de recuperação.');
        }

        // 4. Gerar Link Personalizado
        // Ajuste o domínio conforme necessário (produção vs dev)
        const baseUrl = "https://sincroapp.com.br";
        const link = `${baseUrl}/reset-password?token=${token}`;

        // 5. Buscar nome do usuário para o e-mail
        let name = '';
        try {
            const userDoc = await admin.firestore().collection("users").doc(userRecord.uid).get();
            if (userDoc.exists) {
                const userData = userDoc.data();
                name = `${userData.primeiroNome || ''} ${userData.sobrenome || ''}`.trim();
            }
        } catch (e) {
            console.log("Erro ao buscar nome do usuário:", e.message);
        }

        // 6. Enviar para o n8n
        try {
            await sendToWebhook({
                event: 'password_reset_requested',
                email: email,
                name: name,
                link: link
            });
            functions.logger.info(`Webhook de reset enviado.`);
        } catch (e) {
            functions.logger.error(`Erro ao enviar webhook de reset: ${e.message}`);
            // Não falhar a request se o webhook cair, pois o token já foi gerado? 
            // Mas o usuário não recebe o link. Então melhor dar erro ou assumir que o sistema de log vai pegar.
        }

        return { success: true };
    } catch (error) {
        console.error("Erro CRÍTICO ao solicitar redefinição de senha:", error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError('internal', `Erro ao processar solicitação: ${error.message}`);
    }
});

/**
 * Conclui a redefinição de senha usando o Token Customizado
 */
exports.completePasswordReset = functions.https.onCall(async (data, context) => {
    const { token, newPassword } = data;

    if (!token || !newPassword) {
        throw new functions.https.HttpsError('invalid-argument', 'Token e nova senha são obrigatórios.');
    }

    if (newPassword.length < 6) {
        throw new functions.https.HttpsError('invalid-argument', 'A senha deve ter pelo menos 6 caracteres.');
    }

    try {
        // 1. Buscar o token no Firestore
        const snapshot = await admin.firestore().collection('password_resets')
            .where('token', '==', token)
            .limit(1)
            .get();

        if (snapshot.empty) {
            throw new functions.https.HttpsError('not-found', 'Token inválido ou não encontrado.');
        }

        const tokenDoc = snapshot.docs[0];
        const tokenData = tokenDoc.data();

        // 2. Validar Token (Uso e Expiração)
        if (tokenData.used) {
            throw new functions.https.HttpsError('failed-precondition', 'Este link já foi utilizado.');
        }

        const now = Timestamp.now();
        if (tokenData.expiresAt < now) {
            throw new functions.https.HttpsError('failed-precondition', 'Este link expirou.');
        }

        // 3. Atualizar a senha do usuário no Auth
        const userRecord = await admin.auth().getUserByEmail(tokenData.email);
        await admin.auth().updateUser(userRecord.uid, {
            password: newPassword
        });

        // 4. Marcar token como usado
        await tokenDoc.ref.update({
            used: true,
            usedAt: FieldValue.serverTimestamp()
        });

        return { success: true };

    } catch (error) {
        console.error("Erro ao redefinir senha:", error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError('internal', 'Erro ao redefinir senha.');
    }
});

/**
 * Cria uma sessão do Portal do Cliente Stripe
 */
exports.createPortalSession = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Usuário deve estar logado.');
    }

    const { returnUrl } = data;

    try {
        // 1. Buscar o stripeId do usuário no Firestore
        const userDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
        const userData = userDoc.data();

        if (!userData || !userData.stripeId) {
            throw new functions.https.HttpsError('failed-precondition', 'Usuário não possui ID do Stripe.');
        }

        // 2. Criar a sessão do portal
        const session = await stripe.billingPortal.sessions.create({
            customer: userData.stripeId,
            return_url: returnUrl || 'https://sincroapp.com.br', // Fallback URL
            configuration: process.env.STRIPE_PORTAL_CONFIG_ID, // ID da configuração do portal
        });

        return { url: session.url };

    } catch (error) {
        console.error('Erro ao criar sessão do portal:', error);
        throw new functions.https.HttpsError('internal', 'Não foi possível criar a sessão do portal.');
    }
});
