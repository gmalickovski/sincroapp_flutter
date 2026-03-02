const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const saPath = path.resolve(__dirname, '../../serviceAccountKey.json');
let serviceAccount;

try {
    if (fs.existsSync(saPath)) {
        serviceAccount = require(saPath);
        console.log('[FIREBASE] Carregado serviceAccountKey.json local');
    } else if (process.env.FIREBASE_PROJECT_ID && process.env.FIREBASE_PRIVATE_KEY) {
        serviceAccount = {
            projectId: process.env.FIREBASE_PROJECT_ID,
            clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
            privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
        };
        console.log('[FIREBASE] Carregadas credenciais via variáveis de ambiente');
    } else {
        console.warn('[FIREBASE_WARNING] Credenciais do Firebase Admin NÂO encontradas. Push Notifications Firebase desativadas. Coloque o serviceAccountKey.json na raiz do projeto (c:\\dev\\sincro_app_flutter) ou configure no .env.');
    }

    if (serviceAccount) {
        admin.initializeApp({
            credential: admin.credential.cert(serviceAccount)
        });
        console.log('[FIREBASE] Firebase Admin Inicializado com Sucesso.');
    }
} catch (error) {
    console.error('[FIREBASE_ERROR] Falha ao inicializar o Firebase Admin:', error);
}

module.exports = admin;
