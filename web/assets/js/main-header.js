/**
 * SincroApp - Shared Header Component
 * Self-contained with all styles embedded
 * Works on all pages without external CSS dependencies
 */

const HEADER_STYLES = `
<style id="main-header-styles">
/* ================================================
   HEADER COMPONENT - EMBEDDED STYLES
   ================================================ */

/* Header Core */
.header {
    background-color: rgba(17, 24, 39, 0.95) !important;
    backdrop-filter: blur(10px);
    -webkit-backdrop-filter: blur(10px);
    border-bottom: 1px solid #374151;
    position: fixed;
    top: 0;
    left: 0;
    z-index: 100;
    padding: 16px 0;
    width: 100%;
}

/* Body padding to compensate for fixed header */
body {
    padding-top: 80px !important;
}

.header-container {
    display: flex;
    justify-content: space-between;
    align-items: center;
    max-width: 100%;
    margin: 0;
    padding: 0 16px;
    width: 100%;
    position: relative;
    height: 48px;
}

@media (min-width: 768px) {
    .header-container {
        padding: 0 40px;
    }
}

/* ===== HAMBURGER BUTTON ===== */
/* ALWAYS visible on mobile by default */
.hamburger-btn,
#menu-toggle.hamburger-btn {
    display: flex !important;
    flex-direction: column !important;
    justify-content: center !important;
    align-items: center !important;
    gap: 5px !important;
    width: 28px !important;
    height: 28px !important;
    background: transparent !important;
    border: none !important;
    cursor: pointer !important;
    z-index: 60 !important;
    padding: 4px !important;
    flex-shrink: 0 !important;
}

/* HIDE hamburger on desktop */
@media (min-width: 768px) {
    .hamburger-btn,
    #menu-toggle.hamburger-btn {
        display: none !important;
        visibility: hidden !important;
    }
}

.hamburger-line,
.hamburger-btn .hamburger-line,
#menu-toggle .hamburger-line {
    display: block !important;
    width: 20px !important;
    height: 2px !important;
    min-height: 2px !important;
    background-color: #FFFFFF !important;
    background: #FFFFFF !important;
    border-radius: 1px !important;
    transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1) !important;
    transform-origin: center !important;
    margin: 0 !important;
    padding: 0 !important;
}

.hamburger-btn.active .hamburger-line:nth-child(1) {
    transform: translateY(7px) rotate(45deg);
}

.hamburger-btn.active .hamburger-line:nth-child(2) {
    opacity: 0;
    transform: translateX(10px);
}

.hamburger-btn.active .hamburger-line:nth-child(3) {
    transform: translateY(-7px) rotate(-45deg);
}

/* ===== LOGO ===== */
.logo-link {
    display: flex;
    align-items: center;
    text-decoration: none;
    position: absolute;
    left: 50%;
    transform: translateX(-50%);
}

@media (min-width: 768px) {
    .logo-link {
        position: static;
        transform: none;
    }
}

.logo-svg-main {
    height: 28px;
    width: auto;
    display: block;
}

@media (min-width: 768px) {
    .logo-svg-main {
        height: 32px;
    }
}

/* ===== DESKTOP NAV ===== */
/* HIDDEN on mobile by default */
.header-nav-center {
    display: none;
    align-items: center;
    gap: 24px;
    position: absolute;
    left: 50%;
    transform: translateX(-50%);
}

/* SHOW nav on desktop */
@media (min-width: 768px) {
    .header-nav-center {
        display: flex !important;
    }
}

.nav-link {
    font-size: 14px;
    font-weight: 500;
    color: #9CA3AF;
    transition: all 0.3s ease;
    text-decoration: none;
    padding: 8px 16px;
    border-radius: 9999px;
    position: relative;
    font-family: 'Poppins', -apple-system, sans-serif;
    white-space: nowrap;
}

.nav-link:hover {
    color: #FFFFFF;
    background-color: rgba(255, 255, 255, 0.05);
}

.nav-link.active {
    color: #a78bfa;
    background-color: rgba(124, 58, 237, 0.15);
    box-shadow: 0 0 10px rgba(139, 92, 246, 0.1);
    border: 1px solid rgba(139, 92, 246, 0.2);
}

/* ===== HEADER ACTIONS (App Button) ===== */
.header-actions {
    display: flex;
    align-items: center;
    flex-shrink: 0;
}

.btn-outline {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    padding: 8px 20px;
    border: 1px solid #374151;
    border-radius: 9999px;
    font-size: 14px;
    font-weight: 500;
    color: #FFFFFF;
    background-color: transparent;
    transition: all 0.3s ease;
    text-decoration: none;
    white-space: nowrap;
    font-family: 'Poppins', -apple-system, sans-serif;
}

.btn-outline:hover {
    border-color: #7C3AED;
    color: #7C3AED;
    background-color: rgba(124, 58, 237, 0.1);
}

.btn-text-full {
    display: none;
}

.btn-text-short {
    display: inline;
}

@media (min-width: 640px) {
    .btn-text-full {
        display: inline;
    }
    .btn-text-short {
        display: none;
    }
}

/* ===== MOBILE MENU OVERLAY ===== */
.mobile-menu-overlay {
    position: absolute;
    top: 100%;
    left: 0;
    width: 100%;
    background-color: rgba(17, 24, 39, 0.98);
    backdrop-filter: blur(20px);
    -webkit-backdrop-filter: blur(20px);
    border-bottom: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 0 0 24px 24px;
    box-shadow: 0 10px 30px rgba(0, 0, 0, 0.5);
    transform-origin: top;
    transform: scaleY(0);
    opacity: 0;
    visibility: hidden;
    transition: all 0.4s cubic-bezier(0.16, 1, 0.3, 1);
    z-index: 50;
    overflow: hidden;
}

/* HIDE mobile menu on desktop */
@media (min-width: 768px) {
    .mobile-menu-overlay {
        display: none !important;
    }
}

.mobile-menu-overlay.open {
    transform: scaleY(1);
    opacity: 1;
    visibility: visible;
}

.mobile-menu-inner {
    padding: 16px;
    display: flex;
    flex-direction: column;
    gap: 4px;
}

.mobile-nav-link {
    display: block;
    padding: 14px 16px;
    border-radius: 12px;
    font-size: 16px;
    font-weight: 500;
    color: #9CA3AF;
    text-decoration: none;
    transition: all 0.2s ease;
    font-family: 'Poppins', -apple-system, sans-serif;
}

.mobile-nav-link:hover {
    color: #FFFFFF;
    background-color: rgba(255, 255, 255, 0.05);
}

.mobile-nav-link.active {
    color: #FFFFFF;
    background-color: rgba(124, 58, 237, 0.15);
    border-left: 3px solid #7C3AED;
}
</style>
`;

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
    // 1. Inject embedded styles if not already present
    if (!document.getElementById('main-header-styles')) {
        document.head.insertAdjacentHTML('beforeend', HEADER_STYLES);
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
