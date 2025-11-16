// firebase-config.js
// Configuração do Firebase para o SincroApp Web

// Detecta ambiente
const isLocalhost = Boolean(
  window.location.hostname === 'localhost' ||
  window.location.hostname === '[::1]' ||
  window.location.hostname === '127.0.0.1'
);

// Configuração do Firebase (sincroapp-529cc - PROJETO CORRETO)
const firebaseConfig = {
  apiKey: "AIzaSyCxP5jLEiYyL5hTBqPgawsL4XJ6k_VKHd8",
  authDomain: "sincroapp-529cc.firebaseapp.com",
  projectId: "sincroapp-529cc",
  storageBucket: "sincroapp-529cc.firebasestorage.app",
  messagingSenderId: "1011842661481",
  appId: "1:1011842661481:web:e85b3aa24464e12ae2b6f8",
  measurementId: "G-JVW0L403K9"
};

// Inicializa Firebase
firebase.initializeApp(firebaseConfig);

// Referências aos serviços
const auth = firebase.auth();
const db = firebase.firestore();

// Configuração do App Check
if (isLocalhost) {
  // DEBUG: Ativa debug token
  console.log('🛠️ Modo DEBUG: App Check debug token ativado');
  self.FIREBASE_APPCHECK_DEBUG_TOKEN = true;
  
  // Conecta aos emuladores
  console.log('🔧 Conectando aos emuladores locais...');
  db.useEmulator('localhost', 8081);
  auth.useEmulator('http://localhost:9098');
  
  // Inicializa App Check com debug provider
  const appCheck = firebase.appCheck();
  appCheck.activate(
    new firebase.appCheck.CustomProvider({
      getToken: () => Promise.resolve({ token: 'debug-token', expireTimeMillis: Date.now() + 3600000 })
    }),
    true // isTokenAutoRefreshEnabled
  );
} else {
  // PRODUÇÃO: Usa reCAPTCHA v3
  console.log('🚀 Modo PRODUÇÃO: Usando reCAPTCHA v3');
  const appCheck = firebase.appCheck();
  appCheck.activate(
    '6LeC__ArAAAAAJUbYkba086MP-cCJBolbjLcm_uU', // reCAPTCHA site key
    true // isTokenAutoRefreshEnabled
  );
}

// Listener de mudanças de autenticação
auth.onAuthStateChanged((user) => {
  if (user) {
    console.log('✅ Usuário autenticado:', user.email);
    // Atualiza UI se necessário
    updateAuthUI(true, user);
  } else {
    console.log('❌ Usuário não autenticado');
    updateAuthUI(false, null);
  }
});

// Função helper para atualizar UI
function updateAuthUI(isAuthenticated, user) {
  const loginBtn = document.getElementById('btn-login');
  const registerBtn = document.getElementById('btn-register');
  
  if (isAuthenticated && user) {
    // Usuário logado: esconde botões de auth e mostra "Ir para App"
    if (loginBtn) loginBtn.style.display = 'none';
    if (registerBtn) {
      registerBtn.textContent = 'Abrir App';
      registerBtn.onclick = () => {
        window.location.href = '/'; // Redireciona para o Flutter app
      };
    }
  } else {
    // Usuário não logado: mostra botões normais
    if (loginBtn) loginBtn.style.display = 'block';
    if (registerBtn) {
      registerBtn.textContent = 'Começar Grátis';
      registerBtn.onclick = handleRegister;
    }
  }
}

console.log('✅ Firebase inicializado com sucesso!');
