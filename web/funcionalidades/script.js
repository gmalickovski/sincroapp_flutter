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
        // 1. Load detail IMMEDIATELY (Performance Fix)
        // "O correto é que fosse instantaneo"
        loadFeatureDetail(featureId);

        // 2. Fetch full list in background for navigation (Next Button)
        fetchFeatures().then(() => {
            // Re-render ONLY the navigation part (Header Right)
            // We pass true as second arg to indicate "only nav update" if possible, 
            // or just rely on the fact that loadFeatureDetail is cheap? 
            // Better: Create specific function or just call renderFeatureNav
            updateFeatureNavigation(featureId);
        });
    } else {
        fetchFeatures();
    }

    // Setup filter buttons (desktop)
    filterButtons.forEach(btn => {
        btn.addEventListener('click', () => {
            currentFilter = btn.dataset.filter;
            filterButtons.forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            // Sync with dropdown
            syncDropdownWithFilter(currentFilter);
            renderFeatures();
        });
    });

    // Setup filter dropdown (mobile)
    const filterDropdownBtn = document.getElementById('filterDropdownBtn');
    const filterDropdownMenu = document.getElementById('filterDropdownMenu');
    const filterDropdownLabel = document.getElementById('filterDropdownLabel');
    const filterDropdownItems = document.querySelectorAll('.filter-dropdown-item');

    if (filterDropdownBtn && filterDropdownMenu) {
        // Toggle dropdown
        filterDropdownBtn.addEventListener('click', (e) => {
            e.stopPropagation();
            filterDropdownBtn.classList.toggle('open');
            filterDropdownMenu.classList.toggle('open');
        });

        // Close dropdown when clicking outside
        document.addEventListener('click', (e) => {
            if (!filterDropdownBtn.contains(e.target) && !filterDropdownMenu.contains(e.target)) {
                filterDropdownBtn.classList.remove('open');
                filterDropdownMenu.classList.remove('open');
            }
        });
    }

    // Setup dropdown items
    filterDropdownItems.forEach(item => {
        item.addEventListener('click', () => {
            currentFilter = item.dataset.filter;

            // Update dropdown UI
            filterDropdownItems.forEach(i => i.classList.remove('active'));
            item.classList.add('active');

            // Update label
            if (filterDropdownLabel) {
                filterDropdownLabel.textContent = item.textContent;
            }

            // Close dropdown
            if (filterDropdownBtn) filterDropdownBtn.classList.remove('open');
            if (filterDropdownMenu) filterDropdownMenu.classList.remove('open');

            // Sync with desktop buttons
            filterButtons.forEach(b => b.classList.remove('active'));
            const matchingDesktopBtn = Array.from(filterButtons).find(b => b.dataset.filter === currentFilter);
            if (matchingDesktopBtn) matchingDesktopBtn.classList.add('active');

            renderFeatures();
        });
    });

    // Helper function to sync dropdown with desktop filter
    function syncDropdownWithFilter(filter) {
        filterDropdownItems.forEach(item => {
            item.classList.remove('active');
            if (item.dataset.filter === filter) {
                item.classList.add('active');
                if (filterDropdownLabel) {
                    filterDropdownLabel.textContent = item.textContent;
                }
            }
        });
    }

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
        const response = await fetch('/api/features?context=blog');
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
                ${feature.version ? `<span class="version">v${feature.version}</span>` : ''}
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

    // 3. Scroll to Top (Fix "Scroll pela metade")
    window.scrollTo(0, 0);

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

    // Populate the sticky header with title, tags, and meta
    const headerInfo = document.getElementById('detailHeaderInfo');
    if (headerInfo) {
        headerInfo.innerHTML = `
            <div class="header-title-row">
                <h1>${feature.name}</h1>
            </div>
            </div>
            <div class="header-meta-row">
                <div class="tags">${tags}</div>
                <div class="article-meta">
                    <span>
                        <span class="material-icons">event</span>
                        ${createdDate}
                    </span>
                    <span>
                        <span class="material-icons">update</span>
                        ${updatedDate}
                    </span>
                    ${feature.version ? `
                    <span>
                        <span class="material-icons">new_releases</span>
                        v${feature.version}
                    </span>` : ''}
                </div>
            </div>
        `;
    }

    // Populate Right Header (Next Feature)
    const headerRight = document.querySelector('.header-right');
    if (headerRight) {
        const currentIndex = allFeatures.findIndex(f => f.id === feature.id);

        // Check if there is a next feature
        if (currentIndex !== -1 && currentIndex < allFeatures.length - 1) {
            const nextFeature = allFeatures[currentIndex + 1];
            headerRight.innerHTML = `
                <button class="next-btn-subtle" onclick="openFeature('${nextFeature.id}')" title="Próximo: ${nextFeature.name}">
                    <span class="feature-name">Próxima Página</span>
                    <span class="material-icons">arrow_forward_ios</span>
                </button>
            `;
        } else {
            headerRight.innerHTML = ''; // Clear if last or not found
        }
    }

    // Render content directly without header-section wrapper
    featureArticle.innerHTML = `
        <div class="content">
            ${feature.content || '<p class="empty-content">Conteúdo em breve.</p>'}
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


// Helper to update navigation after background fetch
function updateFeatureNavigation(currentId) {
    const currentIndex = allFeatures.findIndex(f => f.id === currentId);
    const headerRight = document.querySelector('.header-right');

    if (headerRight && currentIndex !== -1 && currentIndex < allFeatures.length - 1) {
        const nextFeature = allFeatures[currentIndex + 1];
        headerRight.innerHTML = `
            <button class="next-btn-subtle" onclick="openFeature('${nextFeature.id}')" title="Próximo: ${nextFeature.name}">
                <span class="feature-name">Próxima Página</span>
                <span class="material-icons">arrow_forward_ios</span>
            </button>
        `;
    }
}

// ================================================
// DYNAMIC LAYOUT FIX (FIXED HEADER OVERLAP)
// ================================================
function adjustContentPadding() {
    const detailHeader = document.querySelector('.detail-header');
    const contentContainer = document.querySelector('.detail-content-clean');

    if (detailHeader && contentContainer) {
        // Measure heights
        const detailHeaderHeight = detailHeader.offsetHeight;
        // Main header is fixed at 80px (desktop) or varying on mobile? 
        // Let's assume 80px if .header-container exists, or measure it if sticky
        const mainHeader = document.getElementById('main-header'); // From main-header.js
        const mainHeaderHeight = mainHeader ? mainHeader.offsetHeight : 80;

        // Calculate total top offset
        // Main Header (80px) + Detail Header (variable) - TIGHTENING (100px)
        // Subtracting to pull content closer to header, removing the gap
        const finalPadding = mainHeaderHeight + detailHeaderHeight - 100;

        // Override CSS with !important to win over any CSS rules
        contentContainer.style.setProperty('padding-top', `${finalPadding}px`, 'important');
    }
}

// Run on load, resize, and when content changes (e.g. render)
window.addEventListener('load', adjustContentPadding);
window.addEventListener('resize', adjustContentPadding);

// Hook into render loop
const originalRenderFeatureDetail = renderFeatureDetail;
renderFeatureDetail = function (feature) {
    originalRenderFeatureDetail(feature);
    // Wait for DOM update
    setTimeout(adjustContentPadding, 50); // Small delay for layout calculation
};
