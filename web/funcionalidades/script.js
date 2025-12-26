// ================================================
// FUNCIONALIDADES PAGE - SincroApp
// ================================================

// State
let allFeatures = [];
let currentFilter = 'all';
let searchTerm = '';

// DOM Elements
const featuresGrid = document.getElementById('featuresGrid');
const featuresFeed = document.getElementById('featuresFeed');
const featureDetail = document.getElementById('featureDetail');
const featureArticle = document.getElementById('featureArticle');
const filterButtons = document.querySelectorAll('.filter-btn');
const searchInput = document.getElementById('searchInput');

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    // Check for URL parameter (deep link to feature)
    const urlParams = new URLSearchParams(window.location.search);
    const featureId = urlParams.get('id');

    if (featureId) {
        loadFeatureDetail(featureId);
    } else {
        fetchFeatures();
    }

    // Setup filter buttons
    filterButtons.forEach(btn => {
        btn.addEventListener('click', () => {
            currentFilter = btn.dataset.filter;
            filterButtons.forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            renderFeatures();
        });
    });

    // Setup search inputs (hero and compact)
    const compactSearchInput = document.querySelector('.compact-search-input');

    if (searchInput) {
        searchInput.addEventListener('input', (e) => {
            searchTerm = e.target.value.toLowerCase().trim();
            // Sync with compact search
            if (compactSearchInput) {
                compactSearchInput.value = e.target.value;
            }
            renderFeatures();
        });
    }

    if (compactSearchInput) {
        compactSearchInput.addEventListener('input', (e) => {
            searchTerm = e.target.value.toLowerCase().trim();
            // Sync with hero search
            if (searchInput) {
                searchInput.value = e.target.value;
            }
            renderFeatures();
        });
    }

    // Mobile search toggle functionality
    const searchToggleBtn = document.getElementById('searchToggleBtn');
    const searchCloseBtn = document.getElementById('searchCloseBtn');
    const searchBox = document.getElementById('searchBox');

    if (searchToggleBtn && searchBox) {
        searchToggleBtn.addEventListener('click', () => {
            searchBox.classList.add('expanded');
            // Focus on input when opened
            const input = searchBox.querySelector('input');
            if (input) {
                setTimeout(() => input.focus(), 100);
            }
        });
    }

    if (searchCloseBtn && searchBox) {
        searchCloseBtn.addEventListener('click', () => {
            searchBox.classList.remove('expanded');
            // Clear search when closed
            if (searchInput) {
                searchInput.value = '';
                searchTerm = '';
                renderFeatures();
            }
        });
    }

    // Close search box when clicking outside on mobile
    document.addEventListener('click', (e) => {
        if (searchBox && searchBox.classList.contains('expanded')) {
            if (!searchBox.contains(e.target) && !searchToggleBtn.contains(e.target)) {
                searchBox.classList.remove('expanded');
            }
        }
    });

    // Note: Previous scroll animation code was removed in favor of native CSS sticky positioning
    // for better performance and natural scroll feel.
});

// Fetch all features
async function fetchFeatures() {
    try {
        const response = await fetch('/api/features');
        const data = await response.json();

        if (data.features && data.features.length > 0) {
            allFeatures = data.features;
            renderFeatures();
        } else {
            showNoResults();
        }
    } catch (error) {
        console.error('Erro ao buscar funcionalidades:', error);
        featuresGrid.innerHTML = `
            <div class="no-results">
                <span class="material-icons">error_outline</span>
                <p>Erro ao carregar funcionalidades. Tente novamente.</p>
            </div>
        `;
    }
}

// Render features grid
function renderFeatures() {
    let filtered = allFeatures;

    // Apply plan filter
    if (currentFilter !== 'all') {
        filtered = filtered.filter(f => f.plans.includes(currentFilter));
    }

    // Apply search filter
    if (searchTerm) {
        filtered = filtered.filter(f => {
            const nameMatch = f.name.toLowerCase().includes(searchTerm);
            const descMatch = (f.shortDescription || '').toLowerCase().includes(searchTerm);
            const planMatch = f.plans.some(p => p.toLowerCase().includes(searchTerm));
            return nameMatch || descMatch || planMatch;
        });
    }

    if (filtered.length === 0) {
        showNoResults();
        return;
    }

    featuresGrid.innerHTML = filtered.map(feature => createFeatureCard(feature)).join('');
}

// Create feature card HTML
function createFeatureCard(feature) {
    const tags = feature.plans.map(plan =>
        `<span class="tag ${plan}">${plan}</span>`
    ).join('');

    const updatedDate = formatDate(feature.updatedAt);

    return `
        <div class="feature-card" onclick="openFeature('${feature.id}')">
            <h3>${feature.name}</h3>
            <p class="description">${feature.shortDescription || 'Clique para saber mais'}</p>
            <div class="tags">${tags}</div>
            <div class="meta">
                <span>Atualizado: ${updatedDate}</span>
                <span class="version">v${feature.version}</span>
            </div>
        </div>
    `;
}

// Format date to Brazilian format
function formatDate(dateString) {
    if (!dateString) return 'N/A';
    const date = new Date(dateString);
    return date.toLocaleDateString('pt-BR', {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric'
    });
}

// Show no results message
function showNoResults() {
    featuresGrid.innerHTML = `
        <div class="no-results">
            <span class="material-icons">search_off</span>
            <p>Nenhuma funcionalidade encontrada para este filtro.</p>
        </div>
    `;
}

// Open feature detail
function openFeature(id) {
    window.history.pushState({}, '', `?id=${id}`);
    loadFeatureDetail(id);
}

// Load feature detail
async function loadFeatureDetail(id) {
    // Hide hero and filters
    const heroSection = document.getElementById('heroSection');
    const filtersSection = document.getElementById('filtersSection');
    if (heroSection) heroSection.style.display = 'none';
    if (filtersSection) filtersSection.style.display = 'none';
    featuresFeed.style.display = 'none';
    featureDetail.style.display = 'block';

    featureArticle.innerHTML = `
        <div class="loading">
            <span class="material-icons spin">sync</span>
            <p>Carregando...</p>
        </div>
    `;

    try {
        const response = await fetch(`/api/features/${id}`);
        const data = await response.json();

        if (data.feature) {
            renderFeatureDetail(data.feature);
        } else {
            featureArticle.innerHTML = `
                <div class="no-results">
                    <span class="material-icons">error_outline</span>
                    <p>Funcionalidade não encontrada.</p>
                </div>
            `;
        }
    } catch (error) {
        console.error('Error fetching feature:', error);
        featureArticle.innerHTML = `
            <div class="no-results">
                <span class="material-icons">error_outline</span>
                <p>Erro ao carregar funcionalidade.</p>
            </div>
        `;
    }
}

// Render feature detail article
function renderFeatureDetail(feature) {
    const tags = feature.plans.map(plan =>
        `<span class="tag ${plan}">${plan}</span>`
    ).join('');

    const createdDate = formatDate(feature.createdAt);
    const updatedDate = formatDate(feature.updatedAt);

    featureArticle.innerHTML = `
        <div class="header-section">
            <h1>${feature.name}</h1>
            <div class="tags" style="margin-bottom: 16px;">${tags}</div>
            <div class="article-meta">
                <span>
                    <span class="material-icons">event</span>
                    Publicado: ${createdDate}
                </span>
                <span>
                    <span class="material-icons">update</span>
                    Atualizado: ${updatedDate}
                </span>
                <span>
                    <span class="material-icons">new_releases</span>
                    Versão: ${feature.version}
                </span>
            </div>
        </div>
        <div class="content">
            ${feature.content || '<p>Conteúdo em breve.</p>'}
        </div>
    `;
}

// Show feed (back button)
function showFeed() {
    window.history.pushState({}, '', window.location.pathname);
    featureDetail.style.display = 'none';
    // Show hero and filters
    const heroSection = document.getElementById('heroSection');
    const filtersSection = document.getElementById('filtersSection');
    if (heroSection) heroSection.style.display = '';
    if (filtersSection) filtersSection.style.display = '';
    featuresFeed.style.display = 'block';

    if (allFeatures.length === 0) {
        fetchFeatures();
    }
}

// Handle browser back button
window.addEventListener('popstate', () => {
    const urlParams = new URLSearchParams(window.location.search);
    const featureId = urlParams.get('id');

    if (featureId) {
        loadFeatureDetail(featureId);
    } else {
        showFeed();
    }
});

// Mobile Menu Logic with Animated Hamburger & Overlay
// Mobile Menu Logic// Mobile Menu Init
// Handled by main-header.js

// Initial Call
document.addEventListener('DOMContentLoaded', () => {
    // Check for URL parameter (deep link to feature)
    const urlParams = new URLSearchParams(window.location.search);
    const featureId = urlParams.get('id');

    if (featureId) {
        loadFeatureDetail(featureId);
    } else {
        fetchFeatures();
    }

    // Mobile menu is now handled by main-header.js
});
