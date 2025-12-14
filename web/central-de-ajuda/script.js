// Backend URL Selection
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
                <span class="chevron">⌄</span>
            </button>
            <div class="faq-answer">
                ${item.answerHtml}
            </div>
        `;

        faqList.appendChild(div);

        // Add click event (Same logic as before)
        div.querySelector('.faq-question').addEventListener('click', () => {
            const isActive = div.classList.contains('active');

            // Close others
            document.querySelectorAll('.faq-item').forEach(i => {
                i.classList.remove('active');
                i.querySelector('.faq-answer').style.maxHeight = null;
            });

            if (!isActive) {
                div.classList.add('active');
                const answer = div.querySelector('.faq-answer');
                answer.style.maxHeight = answer.scrollHeight + "px";
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

// Category Filter Logic (Updated)
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

    faqTitle.innerText = "Tópico Selecionado";
}
