/**
 * SincroApp - Shared Header Component
 * Self-contained with all styles embedded
 * Works on all pages without external CSS dependencies
 */

// Link to external CSS for specific header styles
const HEADER_CSS_PATH = '/assets/css/header.css';

const HEADER_HTML = `
<header class="header">
    <div class="header-container">
        <!-- Left: Mobile Menu Toggle (Hamburger) -->
        <button id="menu-toggle" class="hamburger-btn" aria-label="Menu">
            <span class="hamburger-line"></span>
            <span class="hamburger-line"></span>
            <span class="hamburger-line"></span>
        </button>

        <!-- Center: Logo -->
        <a href="/" class="logo-link">
            <img src="/assets/images/sincroapp_logo.svg" alt="SincroApp" class="logo-svg-main">
        </a>

        <!-- Desktop Nav (Hidden on Mobile) -->
        <nav class="header-nav-center">
            <a href="/" class="nav-link" data-path="/">Início</a>
            <a href="/funcionalidades/" class="nav-link" data-path="/funcionalidades/">Funcionalidades</a>
            <a href="/planos-e-precos/" class="nav-link" data-path="/planos-e-precos/">Planos</a>
            <a href="/central-de-ajuda/" class="nav-link" data-path="/central-de-ajuda/">Central de Ajuda</a>
        </nav>

        <!-- Right: Button (App) -->
        <div class="header-actions">
            <a href="/app" class="btn-outline">
                <span class="btn-text-full">Ir para o App</span>
                <span class="btn-text-short">App</span>
            </a>
        </div>
    </div>

    <!-- Mobile Menu Dropdown -->
    <div id="mobile-menu" class="mobile-menu-overlay">
        <div class="mobile-menu-inner">
            <a href="/" class="mobile-nav-link" data-path="/">Início</a>
            <a href="/funcionalidades/" class="mobile-nav-link" data-path="/funcionalidades/">Funcionalidades</a>
            <a href="/planos-e-precos/" class="mobile-nav-link" data-path="/planos-e-precos/">Planos</a>
            <a href="/central-de-ajuda/" class="mobile-nav-link" data-path="/central-de-ajuda/">Central de Ajuda</a>
        </div>
    </div>
</header>
`;

function loadHeader() {
    // 1. Inject external CSS if not already present
    if (!document.querySelector(`link[href="${HEADER_CSS_PATH}"]`)) {
        const link = document.createElement('link');
        link.rel = 'stylesheet';
        link.href = HEADER_CSS_PATH;
        document.head.appendChild(link);
    }

    // 2. Inject HTML
    const headerContainer = document.getElementById('main-header');
    if (!headerContainer) {
        console.error('Header container #main-header not found!');
        return;
    }
    headerContainer.innerHTML = HEADER_HTML;

    // 3. Highlight Active Link
    const currentPath = window.location.pathname.replace(/\/$/, "");

    const isActive = (linkPath) => {
        const cleanLinkPath = linkPath.replace(/\/$/, "");
        if (cleanLinkPath === "" && currentPath === "") return true;
        if (cleanLinkPath === "" && currentPath !== "") return false;
        return currentPath === cleanLinkPath || currentPath.startsWith(cleanLinkPath + "/");
    };

    // Desktop links
    document.querySelectorAll('.header-nav-center .nav-link').forEach(link => {
        if (isActive(link.getAttribute('data-path'))) {
            link.classList.add('active');
        }
    });

    // Mobile links
    document.querySelectorAll('#mobile-menu .mobile-nav-link').forEach(link => {
        if (isActive(link.getAttribute('data-path'))) {
            link.classList.add('active');
        }
    });

    // 4. Initialize Mobile Menu Logic
    initMobileMenu();
}

function initMobileMenu() {
    const btn = document.getElementById('menu-toggle');
    const menu = document.getElementById('mobile-menu');

    if (!btn || !menu) return;

    const toggleMenu = (e) => {
        e.stopPropagation();
        const isOpen = menu.classList.contains('open');

        if (isOpen) {
            menu.classList.remove('open');
            btn.classList.remove('active');
        } else {
            menu.classList.add('open');
            btn.classList.add('active');
        }
    };

    // Toggle on button click
    btn.addEventListener('click', toggleMenu);

    // Close when clicking outside
    document.addEventListener('click', (e) => {
        if (menu.classList.contains('open') && !menu.contains(e.target) && !btn.contains(e.target)) {
            menu.classList.remove('open');
            btn.classList.remove('active');
        }
    });

    // Close on ESC key
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && menu.classList.contains('open')) {
            menu.classList.remove('open');
            btn.classList.remove('active');
        }
    });
}
