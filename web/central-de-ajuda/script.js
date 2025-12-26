// Firebase Configuration (PLACEHOLDER - PLEASE REPLACE WITH YOUR KEYS)
// Firebase Configuration
const firebaseConfig = {
    apiKey: "AIzaSyCxP5jLEiYyL5hTBqPgawsL4XJ6k_VKHd8",
    authDomain: "sincroapp-529cc.firebaseapp.com",
    projectId: "sincroapp-529cc",
    storageBucket: "sincroapp-529cc.firebasestorage.app",
    messagingSenderId: "1011842661481",
    appId: "1:1011842661481:web:e85b3aa24464e12ae2b6f8"
};

// Initialize Firebase
if (typeof firebase !== 'undefined') {
    firebase.initializeApp(firebaseConfig);
    const storage = firebase.storage();

    // Connect to Emulator if localhost
    if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
        console.log("Using Firebase Storage Emulator");
        storage.useEmulator('localhost', 9199);
    }
}

// Function to upload image
async function uploadImage(file) {
    if (!file) return null;
    try {
        const auth = firebase.auth();
        // Try to sign in anonymously (required for Prod, usually ignored by Emulator if rules are public)
        if (!auth.currentUser) {
            console.log("Waiting for auth (or skipping if public)...");
            try {
                await auth.signInAnonymously();
            } catch (e) {
                // Suppress verbose error if it's the specific "admin-restricted" one (Anonymous auth disabled)
                if (e.code === 'auth/admin-restricted-operation' || e.code === 'auth/operation-not-allowed') {
                    console.warn("Autenticação anônima desativada no console. Tentando upload público (fallback)...");
                } else {
                    console.warn("Falha na autenticação (provável chave de teste). Prosseguindo...", e);
                }
            }
        }

        const storageRef = firebase.storage().ref();
        const fileName = `feedback_images/${Date.now()}_${file.name}`;
        const fileRef = storageRef.child(fileName);

        console.log("Uploading file to:", fileName);
        const snapshot = await fileRef.put(file);
        const url = await snapshot.ref.getDownloadURL();
        console.log("File available at", url);
        return url;
    } catch (error) {
        console.error("Error uploading image:", error);
        alert("Erro ao fazer upload da imagem. Tente novamente.");
        return null; // Stop submission? or continue without image?
    }
}

// Backend URL Selection
let API_BASE_URL = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1'
    ? 'http://localhost:3000'
    : '';
const isLocal = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1';
// Local: Points directly to Node server (requires cors)
// Prod: Points to Nginx proxy (relative path)
const API_URL = isLocal ? "http://localhost:3000/api/faq" : "/api/faq";

// DOM Elements
const faqList = document.getElementById('faqList');
const searchInput = document.getElementById('searchInput');
const faqTitle = document.getElementById('faq-title');

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    fetchFaq();
});

let allFaqItems = []; // Store fetched items for filtering

async function fetchFaq() {
    faqList.innerHTML = '<div style="text-align: center; color: #9CA3AF;">Carregando perguntas...</div>';

    try {
        const response = await fetch(API_URL);
        const data = await response.json();

        if (data.faq && data.faq.length > 0) {
            allFaqItems = data.faq;
            renderFaq(allFaqItems);
        } else {
            faqList.innerHTML = '<div style="text-align: center; color: #9CA3AF;">Nenhuma pergunta encontrada no momento.</div>';
        }

    } catch (error) {
        console.error("Erro ao carregar FAQ:", error);
        faqList.innerHTML = '<div style="text-align: center; color: #DC2626;">Erro ao carregar perguntas. Tente recarregar a página.</div>';
    }
}

function renderFaq(items) {
    faqList.innerHTML = '';

    items.forEach(item => {
        const div = document.createElement('div');
        div.className = 'faq-item';
        div.setAttribute('data-category', mapCategory(item.category)); // Map Notion select to ID

        div.innerHTML = `
            <button class="faq-question">
                ${item.question}
                <svg class="chevron-icon" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <polyline points="6 9 12 15 18 9"></polyline>
                </svg>
            </button>
            <div class="faq-answer">
                ${item.answer}
            </div>
        `;

        faqList.appendChild(div);

        // Category Names Map
        const categoryNames = {
            "start": "Primeiros Passos",
            "subscription": "Assinatura e Planos",
            "account": "Conta e Segurança",
            "tech": "Solução de Problemas"
        };

        // Add click event
        div.querySelector('.faq-question').addEventListener('click', () => {
            const isActive = div.classList.contains('active');

            // Close others
            document.querySelectorAll('.faq-item').forEach(i => {
                i.classList.remove('active');
                i.querySelector('.faq-answer').style.maxHeight = null;
            });

            if (!isActive) {
                div.classList.add('active');
                const answerElement = div.querySelector('.faq-answer');
                answerElement.style.maxHeight = answerElement.scrollHeight + "px";
            }
        });
    });
}

// Map Notion Categories to our IDs
function mapCategory(notionCategory) {
    const map = {
        "Primeiros Passos": "start",
        "Assinatura e Planos": "subscription",
        "Conta e Segurança": "account",
        "Solução de Problemas": "tech"
    };
    // Normalize string just in case (optional, but good for robustness)
    return map[notionCategory] || "general";
}

// Search Logic (Updated to filter virtual items)
searchInput.addEventListener('input', (e) => {
    const term = e.target.value.toLowerCase();
    const items = document.querySelectorAll('.faq-item');
    let hasResults = false;

    items.forEach(item => {
        const question = item.querySelector('.faq-question').innerText.toLowerCase();
        const answer = item.querySelector('.faq-answer').innerText.toLowerCase();

        if (question.includes(term) || answer.includes(term)) {
            item.style.display = 'block';
            hasResults = true;
        } else {
            item.style.display = 'none';
        }
    });

    faqTitle.innerText = term === '' ? "Perguntas Frequentes" : (hasResults ? "Resultados da busca" : "Nenhum resultado encontrado");
});
// Search Logic
if (searchInput) {
    searchInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') {
            document.getElementById('faq-title').scrollIntoView({ behavior: 'smooth' });
        }
    });

    searchInput.addEventListener('input', (e) => {
        const term = e.target.value.toLowerCase();
        let hasResults = false;

        document.querySelectorAll('.faq-item').forEach(item => {
            const question = item.querySelector('.faq-question').innerText.toLowerCase();
            const answer = item.querySelector('.faq-answer').innerText.toLowerCase();

            if (question.includes(term) || answer.includes(term)) {
                item.style.display = 'block';
                hasResults = true;
            } else {
                item.style.display = 'none';
            }
        });

        // Update Title on Search
        if (term !== '') {
            faqTitle.innerText = hasResults ? "Resultados da busca" : "Nenhum resultado encontrado";
        } else {
            faqTitle.innerText = "Perguntas Frequentes (FAQ)";
        }
    });
}

// Category Filter Logic (Updated Title)
function filterCategory(category) {
    // Scroll to FAQ section start with offset for sticky header
    const faqSection = document.querySelector('.faq');
    const headerHeight = document.querySelector('.header').offsetHeight;
    const targetPosition = faqSection.offsetTop - headerHeight - 20; // 20px extra padding

    window.scrollTo({
        top: targetPosition,
        behavior: 'smooth'
    });

    searchInput.value = '';

    const items = document.querySelectorAll('.faq-item');
    items.forEach(item => {
        if (item.getAttribute('data-category') === category) {
            item.style.display = 'block';
        } else {
            item.style.display = 'none';
        }
    });

    // Map category ID to readable name
    const categoryNames = {
        "start": "Primeiros Passos",
        "subscription": "Assinatura e Planos",
        "account": "Conta e Segurança",
        "tech": "Solução de Problemas",
        "general": "Geral"
    };

    faqTitle.innerText = `Perguntas Frequentes (FAQ) - ${categoryNames[category] || 'Tópico'}`;
}

// Scroll to Support/Feedback Section
function scrollToSupport() {
    const supportSection = document.getElementById('support');
    const headerHeight = document.querySelector('.header').offsetHeight;
    const targetPosition = supportSection.offsetTop - headerHeight - 20;

    window.scrollTo({
        top: targetPosition,
        behavior: 'smooth'
    });
}

// --- Inline Feedback Logic ---

// Removed Modal Open/Close functions

// Toggle Anonymous Checkbox
function toggleAnonymous() {
    const isAnonymous = document.getElementById('anonymousCheckbox').checked;
    const nameGroup = document.getElementById('nameGroup');
    const emailGroup = document.getElementById('emailGroup');

    if (isAnonymous) {
        nameGroup.classList.add('disabled');
        emailGroup.classList.add('disabled');
    } else {
        nameGroup.classList.remove('disabled');
        emailGroup.classList.remove('disabled');
    }
}

// File selected handler
function onFileSelected() {
    const input = document.getElementById('feedback-image');
    const preview = document.getElementById('filePreview');
    const fileName = document.getElementById('fileName');
    const label = document.getElementById('fileUploadLabel');

    if (input.files && input.files[0]) {
        fileName.textContent = input.files[0].name;
        preview.style.display = 'flex';
        // Hide the "Attach" button/label
        if (label) label.style.display = 'none';
        // Input is already hidden via CSS/HTML style, but just in case
        input.style.display = 'none';
    }
}

// Remove attachment
function removeAttachment() {
    const input = document.getElementById('feedback-image');
    const preview = document.getElementById('filePreview');
    const label = document.getElementById('fileUploadLabel');

    input.value = '';
    preview.style.display = 'none';
    if (label) label.style.display = 'flex';
}

// Close Success Modal and Reset
window.closeSuccessModal = function () {
    document.getElementById('successModal').style.display = 'none';
    resetForm();
}

function resetForm() {
    const submitBtn = document.getElementById('submit-feedback');
    if (submitBtn) {
        submitBtn.textContent = 'Enviar Feedback';
        submitBtn.disabled = false;
    }

    // Clear inputs
    document.getElementById('feedback-desc').value = '';
    document.getElementById('feedback-image').value = '';
    removeAttachment();

    // Reset anonymous
    document.getElementById('anonymousCheckbox').checked = false;
    toggleAnonymous();
}

// Custom Select Logic
function toggleSelect() {
    const select = document.getElementById('customSelect');
    select.classList.toggle('open');
}

function selectOption(value, icon, label) {
    document.getElementById('feedbackType').value = value;
    document.getElementById('selectedOption').innerHTML = `
        <span class="option-content">
            <span class="material-icons">${icon}</span> 
            ${label}
        </span>
    `;
    document.getElementById('customSelect').classList.remove('open');
}

// Close select when clicking outside
window.addEventListener('click', function (e) {
    const select = document.getElementById('customSelect');
    if (select && !select.contains(e.target)) {
        select.classList.remove('open');
    }
});

window.submitFeedback = async function submitFeedback() {
    const feedbackType = document.querySelector('.custom-select input[type="hidden"]').value;
    const feedbackDesc = document.getElementById('feedback-desc').value;
    const submitBtn = document.getElementById('submit-feedback');
    const imageInput = document.getElementById('feedback-image');
    const imageFile = imageInput && imageInput.files[0];
    const isAnonymous = document.getElementById('anonymousCheckbox').checked;
    const userName = document.getElementById('feedback-name').value.trim();
    const userEmail = document.getElementById('feedback-email').value.trim();

    // Validation
    if (!feedbackDesc) {
        alert('Por favor, descreva o feedback.');
        return;
    }

    if (!isAnonymous) {
        if (!userName) {
            alert('Por favor, informe seu nome.');
            return;
        }
        if (!userEmail) {
            alert('Por favor, informe seu e-mail.');
            return;
        }
        // Simple email validation
        if (!userEmail.includes('@')) {
            alert('Por favor, informe um e-mail válido.');
            return;
        }
    }

    submitBtn.textContent = 'Enviando...';
    submitBtn.disabled = true;

    try {
        let imageUrl = null;
        if (imageFile) {
            submitBtn.textContent = 'Enviando Imagem...';
            imageUrl = await uploadImage(imageFile);
            if (!imageUrl) {
                submitBtn.textContent = 'Enviar Feedback';
                submitBtn.disabled = false;
                return;
            }
        }

        submitBtn.textContent = 'Enviando Dados...';

        const payload = {
            event: 'user_feedback',
            type: feedbackType || 'general',
            description: feedbackDesc,
            image_url: imageUrl,
            app_version: 'Web Help Center 1.0',
            device_info: navigator.userAgent,
            user_id: isAnonymous ? 'anonymous_web' : 'web_visitor',
            user_email: isAnonymous ? 'anônimo' : userEmail,
            name: isAnonymous ? 'Visitante Anônimo' : userName,
            is_anonymous: isAnonymous,
            timestamp: new Date().toISOString()
        };

        const response = await fetch(`${API_BASE_URL}/api/feedback`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(payload)
        });

        const result = await response.json();

        if (response.ok) {
            // Success: Show Floating Modal
            document.getElementById('successModal').style.display = 'flex';
        } else {
            console.error('Feedback error:', result);
            alert('Erro ao enviar feedback. Tente novamente.');
        }

    } catch (error) {
        console.error('Error submitting feedback:', error);
        alert('Erro de conexão.');
    } finally {
        submitBtn.textContent = 'Enviar Feedback';
        submitBtn.disabled = false;
    }
}

function resetForm() {
    document.getElementById('feedback-name').value = '';
    document.getElementById('feedback-email').value = '';
    document.getElementById('feedback-desc').value = '';
    document.getElementById('anonymousCheckbox').checked = false;
    toggleAnonymous();

    // Reset Dropdown
    document.getElementById('feedbackType').value = '';
    document.getElementById('selectedOption').textContent = 'Selecione um Assunto';

    // Reset File
    removeAttachment();

    // Show Form again
    document.getElementById('inlineSuccessMessage').style.display = 'none';
    const formElements = document.getElementById('feedbackForm').children;
    for (let i = 0; i < formElements.length; i++) {
        if (formElements[i].id !== 'inlineSuccessMessage') {
            formElements[i].style.display = '';
        }
    }
}

// Update toggleAnonymous for new structure
function toggleAnonymous() {
    const isAnonymous = document.getElementById('anonymousCheckbox').checked;
    const nameGroup = document.getElementById('nameGroup');
    const emailGroup = document.getElementById('emailGroup');

    if (isAnonymous) {
        nameGroup.classList.add('disabled');
        emailGroup.classList.add('disabled');
    } else {
        nameGroup.classList.remove('disabled');
        emailGroup.classList.remove('disabled');
    }
}


/* Standardized Mobile Menu Logic */
document.addEventListener('DOMContentLoaded', () => {
    const menuToggle = document.getElementById('menu-toggle');
    const mobileMenu = document.getElementById('mobile-menu');
    const iconOpen = document.getElementById('menu-icon-open');
    const iconClose = document.getElementById('menu-icon-close');

    if (menuToggle && mobileMenu) {
        menuToggle.addEventListener('click', () => {
            const isHidden = mobileMenu.classList.contains('hidden');
            if (isHidden) {
                // Open
                mobileMenu.style.display = 'block';
                mobileMenu.classList.remove('hidden');
                iconOpen.classList.add('hidden');
                iconOpen.style.display = 'none';
                iconClose.classList.remove('hidden');
                iconClose.style.display = 'block';
            } else {
                // Close
                mobileMenu.style.display = 'none';
                mobileMenu.classList.add('hidden');
                iconOpen.classList.remove('hidden');
                iconOpen.style.display = 'block';
                iconClose.classList.add('hidden');
                iconClose.style.display = 'none';
            }
        });
    }
});
