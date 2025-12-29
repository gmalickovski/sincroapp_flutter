document.addEventListener('DOMContentLoaded', () => {
    // Initialize Header
    if (typeof loadHeader === 'function') {
        loadHeader();
    }

    // Initialize AOS
    if (typeof AOS !== 'undefined') {
        AOS.init({
            duration: 800,
            once: true,
            offset: 50
        });
    }

    fetchAboutData();
});

async function fetchAboutData() {
    const sincroContainer = document.getElementById('about-sincroapp-container');
    const teamContainer = document.getElementById('about-team-container');

    try {
        const response = await fetch('/api/about');
        if (!response.ok) throw new Error('Failed to fetch data');

        const data = await response.json();

        // 1. Render SincroApp Sections
        if (data.sincroApp && data.sincroApp.length > 0) {
            sincroContainer.innerHTML = ''; // Clear loading

            data.sincroApp.forEach((item, index) => {
                const isEven = index % 2 === 0;

                const html = `
                    <section class="py-20 relative ${isEven ? '' : 'bg-white/5'}">
                        <div class="container mx-auto px-4">
                            <div class="max-w-4xl mx-auto" data-aos="fade-up">
                                <!-- Title Centered -->
                                <h2 class="text-3xl md:text-5xl font-bold mb-12 text-center text-gradient">${item.title}</h2>
                                
                                ${item.image ? `
                                <div class="mb-12 rounded-2xl overflow-hidden shadow-2xl border border-white/10">
                                    <img src="${item.image}" alt="${item.title}" class="w-full h-auto">
                                </div>
                                ` : ''}

                                <!-- Content: Document Style (Left Aligned, Rich Text) -->
                                <div class="prose prose-invert prose md:prose-lg max-w-none text-gray-300 leading-relaxed text-left">
                                    ${item.content}
                                </div>
                            </div>
                        </div>
                    </section>
                `;
                sincroContainer.innerHTML += html;
            });
        } else {
            sincroContainer.innerHTML = '<div class="py-20 text-center text-gray-500"><p>Informações em breve.</p></div>';
        }

        // 2. Render Team Section
        if (data.team && data.team.length > 0) {
            teamContainer.innerHTML = '';

            data.team.forEach((member, index) => {
                const delay = (index % 3) * 100; // Stagger animation

                const html = `
                    <div class="creator-card glass flex flex-col h-full" data-aos="fade-up" data-aos-delay="${delay}">
                        ${member.image ? `
                        <div class="h-[350px] w-full bg-gray-900 overflow-hidden relative group border-b border-gray-800">
                            <img src="${member.image}" class="w-full h-full object-cover transition-transform duration-700 group-hover:scale-105 opacity-90 group-hover:opacity-100" alt="${member.title}">
                            <div class="absolute inset-0 bg-gradient-to-t from-gray-900 via-transparent to-transparent opacity-60"></div>
                        </div>
                        ` : `
                        <div class="h-[150px] bg-gray-900 flex items-center justify-center border-b border-gray-800">
                             <span class="text-4xl">👤</span>
                        </div>
                        `}
                        
                        <div class="p-8 flex-1 flex flex-col">
                            <h3 class="text-2xl font-bold mb-4 font-outfit text-white">${member.title}</h3>
                            <div class="text-gray-400 text-sm leading-relaxed prose prose-invert prose-sm">
                                ${member.content}
                            </div>
                        </div>
                    </div>
                `;
                teamContainer.innerHTML += html;
            });
        } else {
            teamContainer.innerHTML = '<div class="col-span-3 text-center text-gray-500 text-lg">Equipe sendo montada...</div>';
        }

    } catch (error) {
        console.error('Error fetching about data:', error);
        sincroContainer.innerHTML = '<div class="py-20 text-center text-red-400"><p>Erro ao carregar conteúdo.</p></div>';
    }
}
