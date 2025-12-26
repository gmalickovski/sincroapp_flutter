// --- STATE CONFIGURATION ---
// Zonas de aleatoriedade para os cards (Min/Max em %)
const ZONES = {
    mobile: [
        { topMin: 2, topMax: 10, leftMin: 2, leftMax: 8 },      // Card 1 (Top-Left Corner)
        { topMin: 15, topMax: 25, leftMin: -5, leftMax: 5 },    // Card 2 (Upper-Left Edge)
        { bottomMin: 5, bottomMax: 15, leftMin: 2, leftMax: 8 }, // Card 3 (Bottom-Left Corner)
        { topMin: 12, topMax: 20, rightMin: -5, rightMax: 5 },  // Card 4 (Upper-Right Edge)
        { bottomMin: 20, bottomMax: 30, rightMin: -5, rightMax: 5 } // Card 5 (Lower-Right Edge)
    ],
    desktop: [
        { topMin: 5, topMax: 15, leftMin: -5, leftMax: 2 },          // Card 1
        { topMin: 45, topMax: 55, leftMin: -8, leftMax: 0 },         // Card 2
        { bottomMin: 15, bottomMax: 25, leftMin: -5, leftMax: 2 },   // Card 3
        { topMin: 15, topMax: 25, rightMin: -5, rightMax: 2 },       // Card 4
        { bottomMin: 20, bottomMax: 30, rightMin: -8, rightMax: 0 }  // Card 5
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
        if (mobileMockup) {
            mobileMockup.classList.remove('opacity-0', 'translate-y-4', 'invisible');
            mobileMockup.classList.add('opacity-100', 'translate-y-0');
        }
        if (desktopMockup) {
            desktopMockup.classList.remove('opacity-100', 'translate-y-0');
            desktopMockup.classList.add('opacity-0', 'translate-y-4', 'invisible');
        }

        // Buttons state
        if (btnMobile) btnMobile.classList.add('active');
        if (btnDesktop) btnDesktop.classList.remove('active');

        // Randomize & Position Cards for Mobile
        cards.forEach((card, index) => {
            const zone = ZONES.mobile[index];
            if (zone) {
                // Reset all styles first
                card.style.top = ''; card.style.bottom = ''; card.style.left = ''; card.style.right = '';

                // Apply randomized styles
                if (zone.topMin !== undefined) card.style.top = `${getRandom(zone.topMin, zone.topMax)}%`;
                if (zone.bottomMin !== undefined) card.style.bottom = `${getRandom(zone.bottomMin, zone.bottomMax)}%`;
                if (zone.leftMin !== undefined) card.style.left = `${getRandom(zone.leftMin, zone.leftMax)}%`;
                if (zone.rightMin !== undefined) card.style.right = `${getRandom(zone.rightMin, zone.rightMax)}%`;

                // Remove lingering Tailwind positioning classes if any
                card.className = card.className.replace(/top-\[.*?\]|bottom-\[.*?\]|left-\[.*?\]|right-\[.*?\]|-?top-\d+|-?bottom-\d+|-?left-\d+|-?right-\d+|lg:[\w-]+/g, '').trim();
            }
        });

    } else {
        // Toggle Mockups with Fade
        if (mobileMockup) {
            mobileMockup.classList.remove('opacity-100', 'translate-y-0');
            mobileMockup.classList.add('opacity-0', 'translate-y-4', 'invisible');
        }
        if (desktopMockup) {
            desktopMockup.classList.remove('opacity-0', 'translate-y-4', 'invisible');
            desktopMockup.classList.add('opacity-100', 'translate-y-0');
        }

        // Buttons state
        if (btnMobile) btnMobile.classList.remove('active');
        if (btnDesktop) btnDesktop.classList.add('active');

        // Randomize & Position Cards for Desktop with Collision Detection
        const placedCards = []; // Store {top, left, width, height} of placed cards
        const minDistance = 15; // Minimum % distance between card centers

        cards.forEach((card, index) => {
            const zone = ZONES.desktop[index];
            if (zone) {
                // Reset all styles
                card.style.top = ''; card.style.bottom = ''; card.style.left = ''; card.style.right = '';

                // Remove lingering Tailwind positioning classes
                card.className = card.className.replace(/top-\[.*?\]|bottom-\[.*?\]|left-\[.*?\]|right-\[.*?\]|-?top-\d+|-?bottom-\d+|-?left-\d+|-?right-\d+|lg:[\w-]+/g, '').trim();

                let safePos = null;
                let attempts = 0;

                // Try to find a safe position
                while (!safePos && attempts < 50) {
                    // Generate potential position within zone
                    let top = (zone.topMin !== undefined) ? getRandom(zone.topMin, zone.topMax) : null;
                    let bottom = (zone.bottomMin !== undefined) ? getRandom(zone.bottomMin, zone.bottomMax) : null;
                    let left = (zone.leftMin !== undefined) ? getRandom(zone.leftMin, zone.leftMax) : null;
                    let right = (zone.rightMin !== undefined) ? getRandom(zone.rightMin, zone.rightMax) : null;

                    // Normalize to top/left for simple collision check (approximate)
                    // Assuming page height constraint roughly matches width for this abstract checking
                    // In reality, we just check relative distance in %
                    let estTop = top !== null ? top : (100 - bottom);
                    let estLeft = left !== null ? left : (100 - right);

                    // Check collision with already placed cards
                    let collision = false;
                    for (const placed of placedCards) {
                        const dTop = Math.abs(placed.top - estTop);
                        const dLeft = Math.abs(placed.left - estLeft);
                        // Euclidean distance check (roughly)
                        if (Math.sqrt(dTop * dTop + dLeft * dLeft) < minDistance) {
                            collision = true;
                            console.log(`Collision detected for card ${index} with card at ${placed.top},${placed.left}`);
                            break;
                        }
                    }

                    if (!collision) {
                        safePos = { top: estTop, left: estLeft };
                    }
                    attempts++;
                }

                // If no safe pos found, fallback to center of zone
                if (!safePos) {
                    let top = (zone.topMin !== undefined) ? (zone.topMin + zone.topMax) / 2 : null;
                    let left = (zone.leftMin !== undefined) ? (zone.leftMin + zone.leftMax) / 2 : null;
                    // Logic to convert from bottom/right if needed, but zones usually have one anchor
                    // For fallback simplistic:
                    safePos = {
                        top: top || 50,
                        left: left || 50
                    };
                    console.warn(`Card ${index} forced to fallback position to avoid overlap.`);
                }

                // Apply Position
                if (zone.topMin !== undefined) card.style.top = `${safePos.top}%`;
                if (zone.bottomMin !== undefined) card.style.bottom = `${100 - safePos.top}%`;
                if (zone.leftMin !== undefined) card.style.left = `${safePos.left}%`;
                if (zone.rightMin !== undefined) card.style.right = `${100 - safePos.left}%`;

                // Store for next iteration
                placedCards.push(safePos);
            }
        });
    }
}

// Global state to track current features device mode (defaults to mobile)
window.currentFeaturesDevice = 'mobile';

function toggleFeaturesDevice(device) {
    window.currentFeaturesDevice = device;

    // Toggle Desktop Mockups (Existing logic)
    const mobileMockup = document.getElementById('feat-mockup-mobile');
    const desktopMockup = document.getElementById('feat-mockup-desktop');

    // Desktop Layout Buttons
    const btnMobile = document.getElementById('feat-btn-mobile');
    const btnDesktop = document.getElementById('feat-btn-desktop');

    // Mobile Layout Buttons
    const btnMobileSm = document.getElementById('feat-btn-mobile-sm');
    const btnDesktopSm = document.getElementById('feat-btn-desktop-sm');

    // Mobile Layout Container & Image Logic
    const mobileContainer = document.getElementById('feat-mockup-container-mobile');
    const mobileImg = document.getElementById('feat-img-mobile-sm');

    if (device === 'mobile') {
        // --- DESKTOP VIEW LOGIC ---
        if (mobileMockup) {
            mobileMockup.classList.remove('opacity-0', 'translate-y-4', 'invisible');
            mobileMockup.classList.add('opacity-100', 'translate-y-0');
        }
        if (desktopMockup) {
            desktopMockup.classList.remove('opacity-100', 'translate-y-0');
            desktopMockup.classList.add('opacity-0', 'translate-y-4', 'invisible');
        }

        // --- MOBILE VIEW LOGIC ---
        if (mobileContainer) {
            // Revert to Portrait Phone Style
            mobileContainer.className = 'relative w-[140px] aspect-[9/19.5] bg-gray-900 rounded-[2rem] border-[6px] border-gray-800 shadow-2xl overflow-hidden transition-all duration-500 ease-in-out';
        }

        // Force update image to Mobile version for currently visible card
        updateMobileFeatureImage();

        // Button States
        if (btnMobile) btnMobile.classList.add('active');
        if (btnDesktop) btnDesktop.classList.remove('active');
        if (btnMobileSm) btnMobileSm.classList.add('active');
        if (btnDesktopSm) btnDesktopSm.classList.remove('active');

    } else {
        // --- DESKTOP VIEW LOGIC ---
        if (mobileMockup) {
            mobileMockup.classList.remove('opacity-100', 'translate-y-0');
            mobileMockup.classList.add('opacity-0', 'translate-y-4', 'invisible');
        }
        if (desktopMockup) {
            desktopMockup.classList.remove('opacity-0', 'translate-y-4', 'invisible');
            desktopMockup.classList.add('opacity-100', 'translate-y-0');
        }

        // --- MOBILE VIEW LOGIC ---
        if (mobileContainer) {
            // Switch to Landscape Desktop Style
            // w-full max-w-[340px] aspect-[16/10] rounded-t-xl
            mobileContainer.className = 'relative w-full max-w-[340px] aspect-[16/10] bg-gray-900 rounded-t-xl border-[6px] border-gray-800 shadow-2xl overflow-hidden transition-all duration-500 ease-in-out';
        }

        // Force update image to Desktop version
        updateMobileFeatureImage();

        // Button States
        if (btnMobile) btnMobile.classList.remove('active');
        if (btnDesktop) btnDesktop.classList.add('active');
        if (btnMobileSm) btnMobileSm.classList.remove('active');
        if (btnDesktopSm) btnDesktopSm.classList.add('active');
    }
}

// Helper to update image immediately based on active slide
function updateMobileFeatureImage() {
    const mobileImg = document.getElementById('feat-img-mobile-sm');
    const slider = document.getElementById('features-slider-mobile');

    if (!mobileImg || !slider) return;

    // Find the currently active card (highlighted border)
    const activeCard = Array.from(slider.querySelectorAll('.mobile-feature-card')).find(c => c.classList.contains('border-violet-500'));

    if (activeCard) {
        const newSrc = window.currentFeaturesDevice === 'mobile'
            ? activeCard.getAttribute('data-image-mobile')
            : activeCard.getAttribute('data-image-desktop') || activeCard.getAttribute('data-image-mobile'); // Fallback

        if (newSrc && mobileImg.src !== newSrc) {
            mobileImg.style.opacity = '0';
            setTimeout(() => {
                mobileImg.src = newSrc;
                mobileImg.style.opacity = '1';
            }, 200);
        }
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

// Mobile Menu Logic with Animated Hamburger & Overlay
// Mobile Menu Logic moved to main-header.js

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

    // --- Mobile Menu Init ---
    // Handled by main-header.js
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
                <div class="feature-text-item pl-4 border-l-4 border-purple-500/20 transition-all duration-300 hover:border-purple-500 feature-text-group" data-index="${index}">
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
                // Added border-t-4 and transition classes matching desktop style but top-oriented
                mobileCard.className = 'mobile-feature-card min-w-[85vw] snap-center px-4 py-8 border-t-4 border-violet-500/20 flex flex-col justify-start text-left transition-colors duration-300';
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

            // MOBILE: Pagination Dots
            const dotsContainer = document.getElementById('features-mobile-dots');
            if (dotsContainer) {
                if (index === 0) dotsContainer.innerHTML = ''; // Clear on first item
                const dot = document.createElement('div');
                dot.className = 'feature-dot w-2 h-2 rounded-full bg-gray-600 transition-all duration-300';
                dot.setAttribute('data-index', index);
                dotsContainer.appendChild(dot);
            }
        });

        // Initialize Hero Device
        try {
            if (typeof toggleHeroDevice === 'function') {
                toggleHeroDevice('mobile');
            } else {
                console.warn('toggleHeroDevice is not defined yet.');
            }
        } catch (e) { console.error(e); }

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
                // Highlight Card (Active State)
                const card = entry.target;

                // Reset all other cards
                slider.querySelectorAll('.mobile-feature-card').forEach(c => {
                    c.classList.remove('border-violet-500');
                    c.classList.add('border-violet-500/20');

                    // Reset Title Color
                    const title = c.querySelector('h3');
                    if (title) {
                        title.classList.remove('text-transparent', 'bg-clip-text', 'bg-gradient-to-r', 'from-violet-400', 'to-fuchsia-400');
                        title.classList.add('text-white');
                    }
                });

                // Activate current card
                card.classList.remove('border-violet-500/20');
                card.classList.add('border-violet-500');

                // Active Title Color (Match Desktop Gradient)
                const title = card.querySelector('h3');
                if (title) {
                    title.classList.remove('text-white');
                    title.classList.add('text-transparent', 'bg-clip-text', 'bg-gradient-to-r', 'from-violet-400', 'to-fuchsia-400');
                }

                // Update Image logic respecting global device state
                const newSrc = window.currentFeaturesDevice === 'mobile'
                    ? card.getAttribute('data-image-mobile')
                    : card.getAttribute('data-image-desktop') || card.getAttribute('data-image-mobile');

                // const newSrc = card.getAttribute('data-image-mobile'); // OLD
                if (newSrc && mobileImg.src !== newSrc) {
                    mobileImg.style.opacity = '0';
                    setTimeout(() => {
                        mobileImg.src = newSrc;
                        mobileImg.style.opacity = '1';
                    }, 200);
                }

                // Update Dots
                const index = card.getAttribute('data-index');
                const dots = document.querySelectorAll('.feature-dot');
                dots.forEach(d => {
                    d.classList.remove('w-8', 'bg-violet-500');
                    d.classList.add('w-2', 'bg-gray-600');
                });

                const activeDot = document.querySelector(`.feature-dot[data-index="${index}"]`);
                if (activeDot) {
                    activeDot.classList.remove('w-2', 'bg-gray-600');
                    activeDot.classList.add('w-8', 'bg-violet-500');
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
    // Only run if blocks exist
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
