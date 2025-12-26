// --- STATE CONFIGURATION ---
// Zonas de aleatoriedade para os cards (Min/Max em %)
const ZONES = {
    mobile: [
        { topMin: 5, topMax: 15, leftMin: 2, leftMax: 10 },    // Card 1 (TL) - Moved out
        { topMin: 30, topMax: 40, leftMin: 15, leftMax: 25 },   // Card 2 (ML) - Reduced overlap (was 20-35)
        { bottomMin: 15, bottomMax: 25, leftMin: 5, leftMax: 15 }, // Card 3 (BL) - Moved out
        { topMin: 15, topMax: 25, rightMin: 5, rightMax: 15 },  // Card 4 (TR) - Moved out
        { bottomMin: 20, bottomMax: 35, rightMin: 15, rightMax: 25 } // Card 5 (BR) - Reduced overlap (was 20-35)
    ],
    desktop: [
        { topMin: -5, topMax: 5, leftMin: -5, leftMax: 0 },         // Card 1
        { topMin: 35, topMax: 45, leftMin: -10, leftMax: -5 },      // Card 2
        { bottomMin: 5, bottomMax: 15, leftMin: -2, leftMax: 5 },   // Card 3
        { topMin: 5, topMax: 15, rightMin: -5, rightMax: 0 },       // Card 4
        { bottomMin: 10, bottomMax: 25, rightMin: -8, rightMax: -2 } // Card 5
    ]
};

function getRandom(min, max) {
    return Math.floor(Math.random() * (max - min + 1)) + min;
}

// Device Toggle Logic Enhanced
function toggleHeroDevice(device) {
    const mobileMockup = document.getElementById('hero-mockup-mobile');
    const desktopMockup = document.getElementById('hero-mockup-desktop');
    const btnMobile = document.getElementById('hero-btn-mobile');
    const btnDesktop = document.getElementById('hero-btn-desktop');
    const cards = document.querySelectorAll('.hero-floating-card');

    if (device === 'mobile') {
        // Toggle Mockups with Fade
        mobileMockup.classList.remove('opacity-0', 'translate-y-4', 'invisible');
        mobileMockup.classList.add('opacity-100', 'translate-y-0');

        desktopMockup.classList.remove('opacity-100', 'translate-y-0');
        desktopMockup.classList.add('opacity-0', 'translate-y-4', 'invisible');

        // Buttons state
        btnMobile.classList.add('active');
        btnDesktop.classList.remove('active');

        // Randomize & Position Cards for Mobile
        cards.forEach((card, index) => {
            const zone = ZONES.mobile[index];
            // Reset all styles first
            card.style.top = ''; card.style.bottom = ''; card.style.left = ''; card.style.right = '';

            // Apply randomized styles
            if (zone.topMin !== undefined) card.style.top = `${getRandom(zone.topMin, zone.topMax)}%`;
            if (zone.bottomMin !== undefined) card.style.bottom = `${getRandom(zone.bottomMin, zone.bottomMax)}%`;
            if (zone.leftMin !== undefined) card.style.left = `${getRandom(zone.leftMin, zone.leftMax)}%`;
            if (zone.rightMin !== undefined) card.style.right = `${getRandom(zone.rightMin, zone.rightMax)}%`;

            // Remove lingering Tailwind positioning classes if any
            card.className = card.className.replace(/top-\[.*?\]|bottom-\[.*?\]|left-\[.*?\]|right-\[.*?\]|-?top-\d+|-?bottom-\d+|-?left-\d+|-?right-\d+|lg:[\w-]+/g, '').trim();
        });

    } else {
        // Toggle Mockups with Fade
        mobileMockup.classList.remove('opacity-100', 'translate-y-0');
        mobileMockup.classList.add('opacity-0', 'translate-y-4', 'invisible');

        desktopMockup.classList.remove('opacity-0', 'translate-y-4', 'invisible');
        desktopMockup.classList.add('opacity-100', 'translate-y-0');

        // Buttons state
        btnMobile.classList.remove('active');
        btnDesktop.classList.add('active');

        // Randomize & Position Cards for Desktop
        cards.forEach((card, index) => {
            const zone = ZONES.desktop[index];
            // Reset all styles
            card.style.top = ''; card.style.bottom = ''; card.style.left = ''; card.style.right = '';

            // Apply randomized styles
            if (zone.topMin !== undefined) card.style.top = `${getRandom(zone.topMin, zone.topMax)}%`;
            if (zone.bottomMin !== undefined) card.style.bottom = `${getRandom(zone.bottomMin, zone.bottomMax)}%`;
            if (zone.leftMin !== undefined) card.style.left = `${getRandom(zone.leftMin, zone.leftMax)}%`;
            if (zone.rightMin !== undefined) card.style.right = `${getRandom(zone.rightMin, zone.rightMax)}%`;

            // Remove lingering Tailwind positioning classes
            card.className = card.className.replace(/top-\[.*?\]|bottom-\[.*?\]|left-\[.*?\]|right-\[.*?\]|-?top-\d+|-?bottom-\d+|-?left-\d+|-?right-\d+|lg:[\w-]+/g, '').trim();
        });
    }
}

// Initialize positions on load (Mobile Default)
document.addEventListener('DOMContentLoaded', () => {
    // Ensure Mobile Positions are active initially without regex cleaning first time (HTML has default mobile positions)
    // No action needed if HTML matches mobile config.
});


function toggleFeaturesDevice(device) {
    const mobileMockup = document.getElementById('feat-mockup-mobile');
    const desktopMockup = document.getElementById('feat-mockup-desktop');
    const btnMobile = document.getElementById('feat-btn-mobile');
    const btnDesktop = document.getElementById('feat-btn-desktop');

    if (device === 'mobile') {
        mobileMockup.classList.remove('opacity-0', 'translate-y-4', 'invisible');
        mobileMockup.classList.add('opacity-100', 'translate-y-0');

        desktopMockup.classList.remove('opacity-100', 'translate-y-0');
        desktopMockup.classList.add('opacity-0', 'translate-y-4', 'invisible');

        btnMobile.classList.add('active');
        btnDesktop.classList.remove('active');
    } else {
        mobileMockup.classList.remove('opacity-100', 'translate-y-0');
        mobileMockup.classList.add('opacity-0', 'translate-y-4', 'invisible');

        desktopMockup.classList.remove('opacity-0', 'translate-y-4', 'invisible');
        desktopMockup.classList.add('opacity-100', 'translate-y-0');

        btnMobile.classList.remove('active');
        btnDesktop.classList.add('active');
    }
}

// Smooth Scroll to Section
function scrollToSection(id) {
    const element = document.getElementById(id);
    if (element) {
        element.scrollIntoView({ behavior: 'smooth' });
        // Close mobile menu if open
        const mobileMenu = document.getElementById('mobile-menu');
        const menuIconOpen = document.getElementById('menu-icon-open');
        const menuIconClose = document.getElementById('menu-icon-close');
        if (!mobileMenu.classList.contains('hidden')) {
            mobileMenu.classList.add('hidden');
            menuIconOpen.classList.remove('hidden');
            menuIconClose.classList.add('hidden');
        }
    }
}

// Mobile Menu Toggle Logic
document.getElementById('menu-toggle').addEventListener('click', function () {
    const mobileMenu = document.getElementById('mobile-menu');
    const menuIconOpen = document.getElementById('menu-icon-open');
    const menuIconClose = document.getElementById('menu-icon-close');

    if (mobileMenu.classList.contains('hidden')) {
        mobileMenu.classList.remove('hidden');
        menuIconOpen.classList.add('hidden');
        menuIconClose.classList.remove('hidden');
    } else {
        mobileMenu.classList.add('hidden');
        menuIconOpen.classList.remove('hidden');
        menuIconClose.classList.add('hidden');
    }
});

// FAQ Toggle Logic
const faqQuestions = document.querySelectorAll('.faq-question');
faqQuestions.forEach(question => {
    question.addEventListener('click', () => {
        // Close other open FAQs (accordion style)
        faqQuestions.forEach(q => {
            if (q !== question && q.classList.contains('active')) {
                q.classList.remove('active');
            }
        });
        question.classList.toggle('active');
    });
});

// Sticky Scroll Observer & Hero Card Interaction
document.addEventListener('DOMContentLoaded', () => {
    // Inicializa AOS
    AOS.init({
        duration: 800,
        once: true,
        offset: 50,
    });

    // --- Lógica de Interação dos Cards do Hero ---
    const heroCards = document.querySelectorAll('.hero-floating-card');
    const mobileHeroImg = document.getElementById('hero-mockup-mobile-img');
    const desktopHeroImg = document.getElementById('hero-mockup-desktop-img');

    if (heroCards.length > 0) {
        heroCards.forEach(card => {
            const changeImage = () => {
                // Pega as URLs das imagens dos atributos data do card
                const mobileSrc = card.getAttribute('data-mobile-img');
                const desktopSrc = card.getAttribute('data-desktop-img');

                // Atualiza a imagem do mockup ativo
                if (mobileHeroImg && mobileSrc) mobileHeroImg.src = mobileSrc;
                if (desktopHeroImg && desktopSrc) desktopHeroImg.src = desktopSrc;
            };

            // Adiciona eventos para hover (desktop) e touch (mobile)
            card.addEventListener('mouseenter', changeImage);
            // Usa 'touchstart' com passive: true para melhor performance de scroll no mobile
            card.addEventListener('touchstart', changeImage, { passive: true });
        });
    }
    // --- Fim da Lógica dos Cards do Hero ---


    // --- Sticky Scroll Logic (Seção Funcionalidades) ---
    fetchFeatures();
});

async function fetchFeatures() {
    try {
        const response = await fetch('/api/features');
        const data = await response.json();
        const container = document.getElementById('features-scroll-container');

        if (!data.features || data.features.length === 0) {
            container.innerHTML = '<p class="text-center text-gray-500">Nenhuma funcionalidade configurada ainda.</p>';
            return;
        }

        // Clear loading spinner
        if (container) container.innerHTML = '';
        const mobileContainer = document.getElementById('features-slider-mobile');
        if (mobileContainer) mobileContainer.innerHTML = '';

        data.features.forEach((feature, index) => {
            // DESKTOP: Vertical Scroll Blocks
            const block = document.createElement('div');
            block.className = 'feature-block min-h-[80vh] flex flex-col justify-center';

            // Dual Image Support
            const imgMob = feature.imgMobile || feature.image || 'https://picsum.photos/seed/sincro/350/800';
            const imgDesk = feature.imgDesktop || feature.image || 'https://picsum.photos/seed/sincro/1200/800';

            block.setAttribute('data-image-mobile', imgMob);
            block.setAttribute('data-image-desktop', imgDesk);

            block.innerHTML = `
                <div class="feature-text-item pl-4 border-l-4 border-purple-500/20 transition-all duration-300 hover:border-purple-500" data-index="${index}">
                    <h3 class="font-outfit text-2xl md:text-4xl font-bold mb-4 bg-clip-text text-transparent bg-gradient-to-r from-purple-400 to-pink-400">
                        ${feature.name}
                    </h3>
                    <p class="text-gray-400 text-lg md:text-xl leading-relaxed">
                        ${feature.shortDescription}
                    </p>
                </div>
            `;
            if (container) container.appendChild(block);

            // MOBILE: Horizontal Slider Cards
            if (mobileContainer) {
                const mobileCard = document.createElement('div');
                mobileCard.className = 'mobile-feature-card min-w-[85vw] snap-center p-6 bg-gray-800/50 rounded-2xl border border-white/10 backdrop-blur-sm flex flex-col justify-center';
                mobileCard.setAttribute('data-image-mobile', imgMob);
                mobileCard.setAttribute('data-index', index);

                mobileCard.innerHTML = `
                    <h3 class="font-outfit text-2xl font-bold mb-3 text-white">
                        ${feature.name}
                    </h3>
                    <p class="text-gray-400 text-base leading-relaxed">
                        ${feature.shortDescription}
                    </p>
                `;
                mobileContainer.appendChild(mobileCard);
            }
        });

        // Initialize Hero Device
        toggleHeroDevice('mobile');

        // Init Features Observer (Desktop)
        initFeaturesObserver();

        // Init Mobile Slider Observer
        initMobileSliderObserver();

    } catch (error) {
        console.error('Error fetching features:', error);
        const container = document.getElementById('features-scroll-container');
        if (container) container.innerHTML = '<p class="text-center text-red-400">Erro ao carregar funcionalidades.</p>';
    }
}

function initMobileSliderObserver() {
    const slider = document.getElementById('features-slider-mobile');
    const mobileImg = document.getElementById('feat-img-mobile-sm');

    if (!slider || !mobileImg) return;

    // Use Intersection Observer for Horizontal Scroll Snap
    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                const newSrc = entry.target.getAttribute('data-image-mobile');
                if (newSrc && mobileImg.src !== newSrc) {
                    mobileImg.style.opacity = '0';
                    setTimeout(() => {
                        mobileImg.src = newSrc;
                        mobileImg.style.opacity = '1';
                    }, 200);
                }
            }
        });
    }, {
        root: slider,
        threshold: 0.6 // Trigger when card is 60% visible
    });

    const cards = slider.querySelectorAll('.mobile-feature-card');
    cards.forEach(card => observer.observe(card));
}

function initFeaturesObserver() {
    // Only run if desktop container is visible check
    // Actually we can keep it running, as intersection won't trigger if hidden? 
    // IntersectionObserver triggers even if display:none elements are checked? No usually 0x0.

    const blocks = document.querySelectorAll('.feature-block');
    const phoneImg = document.getElementById('feat-img-mobile');
    const desktopImg = document.getElementById('feat-img-desktop');

    if (blocks.length > 0) {
        const observer = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
                const textItem = entry.target.querySelector('.feature-text-item');

                if (entry.isIntersecting) {
                    // Highlight text
                    if (textItem) {
                        textItem.classList.add('active');
                        textItem.classList.remove('border-purple-500/20');
                        textItem.classList.add('border-purple-500');
                    }

                    // Change Images (Mobile & Desktop) - Atualiza ambos
                    const newSrcMobile = entry.target.getAttribute('data-image-mobile');
                    const newSrcDesktop = entry.target.getAttribute('data-image-desktop');

                    if (phoneImg && phoneImg.src !== newSrcMobile) {
                        phoneImg.style.opacity = '0';
                        setTimeout(() => {
                            phoneImg.src = newSrcMobile;
                            phoneImg.style.opacity = '1';
                        }, 200);
                    }

                    if (desktopImg && desktopImg.src !== newSrcDesktop) {
                        desktopImg.style.opacity = '0';
                        setTimeout(() => {
                            desktopImg.src = newSrcDesktop;
                            desktopImg.style.opacity = '1';
                        }, 200);
                    }

                } else {
                    // Remove highlight
                    if (textItem) {
                        textItem.classList.remove('active');
                        textItem.classList.add('border-purple-500/20');
                        textItem.classList.remove('border-purple-500');
                    }
                }
            });
        }, {
            threshold: 0.5, // Center trigger
            rootMargin: "-20% 0px -20% 0px" // Adjusted trigger zone
        });

        blocks.forEach(block => observer.observe(block));
    }
}


// Mock functions to prevent console errors since firebase/external JS is removed for preview
function handleRegister() {
    console.log("Botão de Registro clicado (Simulação)");
    // Redirect to app register
    window.location.href = '/app?page=register';
}

function handleSelectPlan(plan) {
    console.log("Plano selecionado:", plan);
    // Redirect to plans page or app with plan parameters
    window.location.href = '/planos-e-precos';
}
