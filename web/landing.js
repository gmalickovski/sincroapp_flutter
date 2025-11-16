// landing.js
// Scripts principais da landing page do SincroApp

document.addEventListener('DOMContentLoaded', () => {
  // Inicializa AOS (Animate On Scroll)
  AOS.init({
    duration: 800,
    once: true,
    offset: 50,
  });

  // ===== NAVEGAÇÃO =====
  setupNavigation();
  
  // ===== FAQ =====
  setupFAQ();
  
  // ===== MENU MOBILE =====
  setupMobileMenu();
});

// ========================================
// FUNÇÕES DE AUTENTICAÇÃO
// ========================================

/**
 * Abre modal de login ou redireciona para app
 */
async function handleLogin() {
  // Redireciona para a tela de login do app Flutter
  window.location.href = '/app/login';
}

/**
 * Registra novo usuário
 */
async function handleRegister() {
  // Redireciona para a tela de cadastro do app Flutter
  window.location.href = '/app/register';
}

/**
 * Cria documento do usuário no Firestore
 */
async function createUserDocument(user) {
  const displayNameParts = (user.displayName || '').split(' ');
  const primeiroNome = displayNameParts[0] || '';
  const sobrenome = displayNameParts.slice(1).join(' ') || '';
  
  const userData = {
    uid: user.uid,
    email: user.email || '',
    photoUrl: user.photoURL || null,
    primeiroNome,
    sobrenome,
    nomeAnalise: '', // Será preenchido depois
    dataNasc: '', // Será preenchido depois
    isAdmin: false,
    dashboardCardOrder: [
      'PersonalDayCard',
      'QuickTaskCard',
      'GoalsCard',
      'AssistantInsightsCard'
    ],
    dashboardHiddenCards: [],
    subscription: {
      plan: 'free',
      status: 'active',
      validUntil: null,
      startedAt: firebase.firestore.Timestamp.now(),
      aiSuggestionsUsed: 0,
      aiSuggestionsLimit: 0,
      lastAiReset: firebase.firestore.Timestamp.now()
    },
    createdAt: firebase.firestore.Timestamp.now(),
    updatedAt: firebase.firestore.Timestamp.now()
  };
  
  await db.collection('users').doc(user.uid).set(userData);
  console.log('✅ Documento do usuário criado');
}

// ========================================
// FUNÇÕES DE SELEÇÃO DE PLANO
// ========================================

/**
 * Lida com seleção de plano
 */
async function handleSelectPlan(planId) {
  console.log('Plano selecionado:', planId);
  
  // Verifica se usuário está autenticado
  const user = auth.currentUser;
  
  if (!user) {
    // Não está logado: registra primeiro
    console.log('Usuário não autenticado, redirecionando para registro...');
    await handleRegister();
    return;
  }
  
  // Plano gratuito: apenas redireciona
  if (planId === 'free') {
    window.location.href = '/app/';
    return;
  }
  
  // Planos pagos: valida reCAPTCHA e inicia checkout
  showLoading(true);
  
  try {
    // Executa reCAPTCHA v3 para a ação 'checkout'
    const token = await grecaptcha.enterprise.execute(
      '6LeC__ArAAAAAJUbYkba086MP-cCJBolbjLcm_uU',
      { action: 'checkout' }
    );
    
    console.log('✅ Token reCAPTCHA gerado para checkout');
    
    // Valida no backend (isso gera a pontuação que o Firebase precisa!)
    const validateResponse = await fetch('https://us-central1-sincroapp-529cc.cloudfunctions.net/validateRecaptcha', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        token: token,
        action: 'checkout'
      })
    });
    
    const validation = await validateResponse.json();
    
    if (!validation.success) {
      console.warn('⚠️ Verificação reCAPTCHA falhou:', validation);
      showError('Verificação de segurança falhou. Tente novamente.');
      return;
    }
    
    console.log('✅ reCAPTCHA validado. Score:', validation.score);
    
    // Chama função do PaymentService via Cloud Function
    const startCheckout = firebase.functions().httpsCallable('startWebCheckout');
    const result = await startCheckout({ 
      userId: user.uid,
      plan: planId, // 'plus' ou 'premium'
      recaptchaToken: token
    });
    
    if (result.data.checkoutUrl) {
      // Redireciona para página de pagamento do PagBank
      window.location.href = result.data.checkoutUrl;
    } else {
      throw new Error('URL de checkout não recebida');
    }
    
  } catch (error) {
    console.error('❌ Erro ao iniciar checkout:', error);
    showError('Erro ao processar pagamento. Tente novamente.');
  } finally {
    showLoading(false);
  }
}

// ========================================
// UI HELPERS
// ========================================

/**
 * Mostra/esconde overlay de loading
 */
function showLoading(show) {
  const overlay = document.getElementById('loading-overlay');
  if (overlay) {
    if (show) {
      overlay.classList.add('active');
    } else {
      overlay.classList.remove('active');
    }
  }
}

/**
 * Mostra mensagem de erro
 */
function showError(message) {
  alert(message); // TODO: Substituir por toast/modal customizado
}

// ========================================
// NAVEGAÇÃO
// ========================================

/**
 * Configura navegação smooth scroll
 */
function setupNavigation() {
  // Scroll suave para seções
  window.scrollToSection = function(sectionId) {
    const element = document.getElementById(sectionId);
    if (element) {
      element.scrollIntoView({ 
        behavior: 'smooth',
        block: 'start'
      });
      
      // Fecha menu mobile se aberto
      const mobileMenu = document.getElementById('mobile-menu');
      if (mobileMenu && !mobileMenu.classList.contains('hidden')) {
        toggleMobileMenu();
      }
      
      // Atualiza nav ativa
      updateActiveNav(sectionId);
    }
  };
  
  // Observa seções para atualizar nav
  const sections = document.querySelectorAll('section[id]');
  const observerOptions = {
    threshold: 0.3,
    rootMargin: '-50px'
  };
  
  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        updateActiveNav(entry.target.id);
      }
    });
  }, observerOptions);
  
  sections.forEach(section => observer.observe(section));
}

/**
 * Atualiza item ativo na navegação
 */
function updateActiveNav(sectionId) {
  // Remove todos os ativos
  document.querySelectorAll('.nav-button').forEach(btn => {
    btn.style.color = 'var(--text-secondary)';
  });
  
  // Ativa o correto
  const navBtn = document.getElementById(`nav-${sectionId}`);
  if (navBtn) {
    navBtn.style.color = 'var(--text-primary)';
  }
}

// ========================================
// FAQ
// ========================================

/**
 * Configura accordion do FAQ
 */
function setupFAQ() {
  const faqQuestions = document.querySelectorAll('.faq-question');
  
  faqQuestions.forEach(question => {
    question.addEventListener('click', () => {
      const isActive = question.classList.contains('active');
      
      // Fecha todas
      faqQuestions.forEach(q => q.classList.remove('active'));
      
      // Abre a clicada se não estava ativa
      if (!isActive) {
        question.classList.add('active');
      }
    });
  });
}

// ========================================
// MENU MOBILE
// ========================================

/**
 * Configura menu mobile
 */
function setupMobileMenu() {
  const menuToggle = document.getElementById('menu-toggle');
  
  if (menuToggle) {
    menuToggle.addEventListener('click', toggleMobileMenu);
  }
}

/**
 * Toggle menu mobile
 */
function toggleMobileMenu() {
  const mobileMenu = document.getElementById('mobile-menu');
  const iconOpen = document.getElementById('menu-icon-open');
  const iconClose = document.getElementById('menu-icon-close');
  
  if (mobileMenu) {
    const isHidden = mobileMenu.classList.contains('hidden');
    
    if (isHidden) {
      mobileMenu.classList.remove('hidden');
      iconOpen.classList.add('hidden');
      iconClose.classList.remove('hidden');
    } else {
      mobileMenu.classList.add('hidden');
      iconOpen.classList.remove('hidden');
      iconClose.classList.add('hidden');
    }
  }
}

// ========================================
// EXPORTS GLOBAIS
// ========================================
window.handleLogin = handleLogin;
window.handleRegister = handleRegister;
window.handleSelectPlan = handleSelectPlan;
