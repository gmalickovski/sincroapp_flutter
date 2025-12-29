function loadFooter() {
    const footerContainer = document.createElement('footer');
    footerContainer.className = 'footer-global';

    // Add CSS stylesheet if not present
    if (!document.querySelector('link[href*="footer.css"]')) {
        const link = document.createElement('link');
        link.rel = 'stylesheet';
        link.href = '/assets/css/footer.css';
        document.head.appendChild(link);
    }

    footerContainer.innerHTML = `
        <div class="container">
            <div class="footer-grid">
                <!-- 1. Brand -->
                <div class="footer-brand">
                    <h3>
                        <div class="p-2 rounded-lg bg-violet-600 inline-flex items-center justify-center w-8 h-8">
                            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                <path d="M12 12c-2-2.67-4-4-6-4a4 4 0 1 0 0 8c2 0 4-1.33 6-4Zm0 0c2 2.67 4 4 6 4a4 4 0 1 0 0-8c-2 0-4 1.33-6 4Z"/>
                            </svg>
                        </div>
                        SincroApp
                    </h3>
                    <p>Autoconhecimento e produtividade em sintonia com a numerologia e IA.</p>
                </div>

                <!-- 2. Produto -->
                <div class="footer-col">
                    <h4>Produto</h4>
                    <ul class="footer-links">
                        <li><a href="/funcionalidades/">Funcionalidades</a></li>
                        <li><a href="/planos-e-precos/">Planos e Preços</a></li>
                        <li><a href="/app/">Entrar no App</a></li>
                    </ul>
                </div>

                <!-- 3. Empresa -->
                <div class="footer-col">
                    <h4>Empresa</h4>
                    <ul class="footer-links">
                        <li><a href="/sobre/">Sobre Nós</a></li>
                        <li><a href="/central-de-ajuda/">Central de Ajuda</a></li>
                        <li><a href="mailto:contato@sincroapp.com">Contato</a></li>
                    </ul>
                </div>

                <!-- 4. Legal -->
                <div class="footer-col">
                    <h4>Legal</h4>
                    <ul class="footer-links">
                        <li><a href="#">Termos de Uso</a></li>
                        <li><a href="#">Política de Privacidade</a></li>
                    </ul>
                </div>
            </div>

            <div class="footer-bottom">
                <div class="footer-copyright">
                    &copy; ${new Date().getFullYear()} SincroApp. Todos os direitos reservados.
                </div>
                <div class="footer-love">
                    Feito com 💜 por <a href="#" target="_blank" style="color: #A78BFA;">Studio MLK</a>
                </div>
            </div>
        </div>
    `;

    // Replace current footer tag or append to body if footer not found (but usually we have a placeholder)
    // Actually, best practice: Find <div id="main-footer"></div> or just append.
    // Let's modify pages to have <div id="main-footer"></div>
    const existingFooter = document.querySelector('footer') || document.getElementById('main-footer');

    if (existingFooter) {
        existingFooter.replaceWith(footerContainer);
    } else {
        document.body.appendChild(footerContainer);
    }
}

// Auto-load if this script is defer/async, or wait for DOM
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', loadFooter);
} else {
    loadFooter();
}
