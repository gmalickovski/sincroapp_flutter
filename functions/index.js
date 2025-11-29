require('dotenv').config();
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");
// Initialize Stripe with your Secret Key
const stripe = require("stripe")(process.env.STRIPE_SECRET_KEY);

admin.initializeApp();

// URL do webhook do n8n
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
        return res.status(400).send(`Erro Webhook: ${err.message}`);
    }

    const dataObject = event.data.object;

    try {
        // Manipular o evento
        switch (event.type) {
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
                        'subscription.lastPayment': admin.firestore.FieldValue.serverTimestamp()
                    });

                    // Enviar notificação para n8n
                    await sendToWebhook({
                        event: 'subscription_activated',
                        email: userData.email,
                        name: `${userData.primeiroNome || ''} ${userData.sobrenome || ''}`.trim(),
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
                        name: `${userData.primeiroNome || ''} ${userData.sobrenome || ''}`.trim(),
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
                        'subscription.updatedAt': admin.firestore.FieldValue.serverTimestamp()
                    });

                    await sendToWebhook({
                        event: 'subscription_updated',
                        email: userData.email,
                        name: `${userData.primeiroNome || ''} ${userData.sobrenome || ''}`.trim(),
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
                        name: `${userData.primeiroNome || ''} ${userData.sobrenome || ''}`.trim(),
                        userId: userDoc.id
                    });
                }
                break;
            }

            default:
                console.log(`Tipo de evento não tratado: ${event.type}`);
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
        name: `${userData.primeiroNome || ''} ${userData.sobrenome || ''}`.trim(),
        plan: userData.plano || "gratuito",
        userId: userId,
    };

    await sendToWebhook(payload);
    return null;
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
    logger.info(`================ onUserDeleted ACIONADA =================`);

    const firestore = admin.firestore();
    const userDocRef = firestore.collection("users").doc(userId);

    try {
        // --- PASSO 1: Buscar dados do usuário ANTES de deletar ---
        const userDoc = await userDocRef.get();
        let userName = '';
        if (userDoc.exists) {
            const userData = userDoc.data();
            userName = `${userData.primeiroNome || ''} ${userData.sobrenome || ''}`.trim();
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
        logger.error(`Erro ao limpar dados ou enviar webhook para o usuário ${userId}:`, error);
        return { status: "error", message: `Falha no processo de exclusão do usuário ${userId}.` };
    }
});

/**
 * Solicita redefinição de senha personalizada via n8n
 */
exports.requestPasswordReset = functions.https.onCall(async (data, context) => {
    const { email } = data;

    if (!email) {
        throw new functions.https.HttpsError('invalid-argument', 'O e-mail é obrigatório.');
    }

    try {
        // Gera o link de redefinição de senha usando o Admin SDK
        const link = await admin.auth().generatePasswordResetLink(email);

        // Busca dados do usuário para personalizar o e-mail (opcional, mas bom)
        let name = '';
        try {
            const userRecord = await admin.auth().getUserByEmail(email);
            const userDoc = await admin.firestore().collection("users").doc(userRecord.uid).get();
            if (userDoc.exists) {
                const userData = userDoc.data();
                name = `${userData.primeiroNome || ''} ${userData.sobrenome || ''}`.trim();
            }
        } catch (e) {
            // Se não encontrar usuário ou der erro no firestore, apenas segue sem nome
            console.log("Usuário não encontrado no Firestore ou Auth para pegar nome:", e.message);
        }

        // Envia para o n8n
        await sendToWebhook({
            event: 'password_reset_requested',
            email: email,
            name: name,
            link: link
        });

        return { success: true };
    } catch (error) {
        console.error("Erro ao gerar link de redefinição:", error);
        // Não expor erro detalhado de "usuário não encontrado" por segurança (user enumeration)
        if (error.code === 'auth/user-not-found') {
            // Retorna sucesso mesmo se não achar, para não revelar e-mails cadastrados
            return { success: true };
        }
        throw new functions.https.HttpsError('internal', 'Erro ao processar solicitação.');
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
