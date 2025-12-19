// Firebase Configuration (PLACEHOLDER - PLEASE REPLACE WITH YOUR KEYS)
const firebaseConfig = {
    apiKey: "YOUR_API_KEY",
    authDomain: "sincro-app-flutter.firebaseapp.com",
    projectId: "sincro-app-flutter",
    storageBucket: "sincro-app-flutter.firebasestorage.app",
    messagingSenderId: "1765903179777", // Guessed from context or placeholder
    appId: "YOUR_APP_ID"
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
                console.warn("Auth failed (likely invalid key in test mode). Proceeding to upload assuming public rules.", e);
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
                ${item.answerHtml}
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
    document.getElementById('faq-title').scrollIntoView({ behavior: 'smooth' });
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

// --- Feedback Modal Logic ---
const modal = document.getElementById('feedbackModal');

function openFeedbackModal() {
    modal.classList.add('open');
    document.body.style.overflow = 'hidden';
}

function closeFeedbackModal() {
    modal.classList.remove('open');
    document.body.style.overflow = '';
    // Reset form
    document.getElementById('feedback-desc').value = '';
    document.getElementById('feedback-image').value = '';
    document.getElementById('filePreview').style.display = 'none';
    const fileLabel = document.getElementById('fileUploadLabel');
    if (fileLabel) fileLabel.style.display = 'flex'; // Show label

    const nameInput = document.getElementById('feedback-name');
    const emailInput = document.getElementById('feedback-email');
    if (nameInput) nameInput.value = '';
    if (emailInput) emailInput.value = '';
    document.getElementById('anonymousCheckbox').checked = false;
    document.getElementById('nameGroup').classList.remove('disabled');
    document.getElementById('emailGroup').classList.remove('disabled');
}

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

// Success Modal
function showSuccessModal(isAnonymous) {
    const successModal = document.getElementById('successModal');
    const successTitle = document.getElementById('successTitle');
    const successMessage = document.getElementById('successMessage');

    if (isAnonymous) {
        successTitle.textContent = 'Obrigado pelo seu feedback! 💜';
        successMessage.textContent = 'Sua mensagem foi recebida e será analisada pela nossa equipe.';
    } else {
        successTitle.textContent = 'Mensagem Enviada! 🎉';
        successMessage.innerHTML = 'Vamos analisar seu feedback com carinho e, se necessário, retornaremos uma resposta para seu e-mail.<br><br>Agradecemos sua contribuição — ela nos ajuda a melhorar o app cada vez mais!';
    }

    successModal.style.display = 'flex';
}

function closeSuccessModal() {
    document.getElementById('successModal').style.display = 'none';
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
            closeFeedbackModal();
            showSuccessModal(isAnonymous);
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
