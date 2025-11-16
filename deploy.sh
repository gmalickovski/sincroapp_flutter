#!/bin/bash
# Script de deploy automático para SincroApp
# Uso: ./deploy.sh [ambiente]
# Ambientes: dev, staging, production

set -e  # Para na primeira falha

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Funções helper
info() {
    echo -e "${GREEN}✓${NC} $1"
}

warn() {
    echo -e "${YELLOW}!${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
    exit 1
}

# Verifica argumento
ENVIRONMENT=${1:-production}

if [ "$ENVIRONMENT" != "dev" ] && [ "$ENVIRONMENT" != "staging" ] && [ "$ENVIRONMENT" != "production" ]; then
    error "Ambiente inválido. Use: dev, staging ou production"
fi

info "Iniciando deploy para ambiente: $ENVIRONMENT"

# ========================================
# 1. VALIDAÇÕES PRÉ-DEPLOY
# ========================================

info "Verificando pré-requisitos..."

# Verifica se Firebase CLI está instalado
if ! command -v firebase &> /dev/null; then
    error "Firebase CLI não encontrado. Instale com: npm install -g firebase-tools"
fi

# Verifica se Flutter está instalado
if ! command -v flutter &> /dev/null; then
    error "Flutter não encontrado. Instale de: https://flutter.dev"
fi

# Verifica se está logado no Firebase
if ! firebase projects:list &> /dev/null; then
    error "Não está logado no Firebase. Execute: firebase login"
fi

info "Pré-requisitos OK"

# ========================================
# 2. BUILD FLUTTER WEB
# ========================================

info "Iniciando build do Flutter Web..."

# Limpa builds anteriores
rm -rf build/web

# Build otimizado
flutter build web --release --web-renderer canvaskit

if [ $? -ne 0 ]; then
    error "Falha no build do Flutter"
fi

info "Build do Flutter concluído"

# ========================================
# 3. DEPLOY FIREBASE FUNCTIONS
# ========================================

info "Deploy das Firebase Functions..."

cd functions

# Instala dependências (se necessário)
if [ ! -d "node_modules" ]; then
    npm install
fi

cd ..

# Deploy apenas functions
firebase deploy --only functions --project sincroapp-e9cda

if [ $? -ne 0 ]; then
    error "Falha no deploy das Functions"
fi

info "Functions deployadas com sucesso"

# ========================================
# 4. DEPLOY FIREBASE HOSTING (OPCIONAL)
# ========================================

if [ "$ENVIRONMENT" == "production" ]; then
    warn "Deploy via Firebase Hosting foi pulado"
    warn "Para hosting, use VPS conforme VPS_DEPLOY_GUIDE.md"
fi

# Se quiser usar Firebase Hosting ao invés de VPS:
# firebase deploy --only hosting --project sincroapp-e9cda

# ========================================
# 5. UPLOAD PARA VPS (PRODUÇÃO)
# ========================================

if [ "$ENVIRONMENT" == "production" ]; then
    info "Preparando upload para VPS..."
    
    # Configurações VPS (AJUSTE CONFORME SUA VPS)
    VPS_USER="root"
    VPS_HOST="seu-dominio.com"
    VPS_PATH="/var/www/sincroapp"
    
    warn "Configuração VPS:"
    warn "  Usuário: $VPS_USER"
    warn "  Host: $VPS_HOST"
    warn "  Path: $VPS_PATH"
    warn ""
    read -p "Confirma upload para VPS? (y/n) " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Compacta build
        tar -czf sincroapp-web.tar.gz build/web web/landing.html web/landing.js web/firebase-config.js
        
        # Upload
        scp sincroapp-web.tar.gz $VPS_USER@$VPS_HOST:/tmp/
        
        # Extrai na VPS
        ssh $VPS_USER@$VPS_HOST << 'ENDSSH'
cd /var/www/sincroapp
sudo tar -xzf /tmp/sincroapp-web.tar.gz
sudo chown -R www-data:www-data .
sudo systemctl restart nginx
ENDSSH
        
        # Limpa arquivo temporário
        rm sincroapp-web.tar.gz
        
        info "Upload para VPS concluído"
    else
        warn "Upload para VPS cancelado"
    fi
fi

# ========================================
# 6. TESTES PÓS-DEPLOY
# ========================================

info "Deploy concluído!"
info ""
info "Próximos passos:"

if [ "$ENVIRONMENT" == "production" ]; then
    info "  1. Verificar: https://seu-dominio.com"
    info "  2. Testar autenticação"
    info "  3. Testar seleção de plano"
    info "  4. Verificar logs: firebase functions:log"
    info "  5. Monitorar: pm2 logs sincroapp-notifications"
else
    info "  1. Testar localmente: firebase emulators:start"
    info "  2. Acessar: http://localhost:8000/landing.html"
fi

info ""
info "✨ Deploy bem-sucedido!"
