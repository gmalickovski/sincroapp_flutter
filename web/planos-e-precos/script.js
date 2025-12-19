const PRICES = {
    monthly: {
        plus: 29.90,
        premium: 59.90
    },
    annual: {
        plus: 23.90, // 20% OFF approx (29.90 * 0.8 = 23.92) - Let's use clean numbers for Annual equivalence
        premium: 47.90
    }
};

let currentBilling = 'monthly';

// DOM Elements
const btnMonthly = document.getElementById('btn-monthly');
const btnAnnual = document.getElementById('btn-annual');
const pricePlus = document.getElementById('price-plus');
const pricePremium = document.getElementById('price-premium');
const infoPlus = document.getElementById('info-plus');
const infoPremium = document.getElementById('info-premium');

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    fetchPlans();
});

function setBilling(cycle) {
    currentBilling = cycle;

    // Update Buttons
    if (cycle === 'monthly') {
        btnMonthly.classList.add('active');
        btnAnnual.classList.remove('active');
    } else {
        btnMonthly.classList.remove('active');
        btnAnnual.classList.add('active');
    }

    // Update Prices with Animation
    updatePrice(pricePlus, PRICES[cycle].plus);
    updatePrice(pricePremium, PRICES[cycle].premium);

    // Update Info Text
    const text = cycle === 'monthly' ? 'Cobrado mensalmente' : 'Cobrado anualmente';
    infoPlus.innerText = text;
    infoPremium.innerText = text;
}

function updatePrice(element, newValue) {
    element.style.opacity = 0;
    setTimeout(() => {
        element.innerText = newValue.toFixed(2).replace('.', ',');
        element.style.opacity = 1;
    }, 200);
}

async function fetchPlans() {
    try {
        const response = await fetch('/api/plans');
        const data = await response.json();

        // 1. Render Cards (Cascade Data)
        // If the backend returns { cards: {...}, comparison: [...] }
        const cardsData = data.cards || data; // fallback if needed

        renderList('list-free', cardsData.free);
        renderList('list-plus', cardsData.plus);
        renderList('list-premium', cardsData.premium);

        // 2. Render Comparison Table (Full Data)
        if (data.comparison) {
            renderComparison(data.comparison);
        }

    } catch (error) {
        console.error('Erro ao buscar planos:', error);
    }
}

function renderComparison(items) {
    const tbody = document.getElementById('comparison-body');
    tbody.innerHTML = '';

    items.forEach(item => {
        const tr = document.createElement('tr');

        // Feature Name
        const tdName = document.createElement('td');
        tdName.innerText = item.name;
        tr.appendChild(tdName);

        // Checks
        const isFree = item.tags.includes('Essencial');
        const isPlus = item.tags.includes('Essencial') || item.tags.includes('Desperta'); // Cumulative? 
        // Wait, user said "if tags [Desperta, Sinergia], it appears in Desperta col".
        // BUT for comparison table, usually a feature in "Essencial" is ALSO in "Plus" and "Premium".
        // Does the Notion Tag imply EXCLUSIVE or INCLUSIVE?
        // Card Logic implies Exclusive for the list.
        // Table Logic usually implies Inclusive checkmarks.
        // If a feature is "Essencial", it is definitely in Plus/Premium too.
        // Let's assume INCLUSIVE logic for the table based on standard SaaS pricing.
        // If Notion tag has "Essencial", we check ALL columns.
        // If Notion tag has "Desperta", we check Plus and Premium.
        // If Notion tag has "Sinergia", we check Premium only.
        // ACTUAL LOGIC FROM USER: "se na funcionalidade ... tiver as 3 tags... só aparecem na primeira coluna" (FOR CARDS).
        // FOR TABLE: "Checkmarks".
        // Let's look at the tags on the Notion item.
        // If Notion says "Essencial, Desperta, Sinergia" -> It means it's available in all 3.
        // If Notion says "Desperta, Sinergia" -> Available in Plus, Premium.
        // If Notion says "Sinergia" -> Available in Premium.
        // So we just check if the tag is present in the database list.

        tr.appendChild(createCheckCell(item.tags.includes('Essencial')));
        tr.appendChild(createCheckCell(item.tags.includes('Desperta')));
        tr.appendChild(createCheckCell(item.tags.includes('Sinergia')));

        tbody.appendChild(tr);
    });
}

function createCheckCell(isActive) {
    const td = document.createElement('td');
    if (isActive) {
        td.innerHTML = '<span class="material-icons check-icon">check</span>';
    } else {
        td.innerHTML = '<span class="dash-icon">-</span>';
    }
    return td;
}

function toggleComparison() {
    const wrapper = document.getElementById('comparison-wrapper');
    const btn = document.querySelector('.btn-toggle-compare');

    wrapper.classList.toggle('open');
    btn.classList.toggle('open');
}

function renderList(elementId, items) {
    const list = document.getElementById(elementId);
    list.innerHTML = ''; // Clear skeleton

    if (!items || items.length === 0) {
        list.innerHTML = '<li>Sem recursos cadastrados.</li>';
        return;
    }

    items.forEach(item => {
        const li = document.createElement('li');
        li.innerText = item;
        list.appendChild(li);
    });
}
