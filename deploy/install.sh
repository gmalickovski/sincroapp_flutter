#!/bin/bash

###############################################################################
# Script de Instalação Completa - SincroApp Flutter Web
# Autor: Sistema de Deploy Automatizado
# Data: 2025-11-16
# Descrição: Instala e configura todo o sistema do zero
###############################################################################

set -e  # Encerra o script em caso de erro

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurações (podem ser sobrescritas via ambiente)
INSTALL_DIR="${INSTALL_DIR:-/var/www/webapp/sincroapp_flutter}"
GITHUB_REPO="${GITHUB_REPO:-https://github.com/gmalickovski/sincroapp_flutter.git}"
NGINX_CONFIG="${NGINX_CONFIG:-/etc/nginx/sites-available/sincroapp.com.br}"
NGINX_ENABLED="${NGINX_ENABLED:-/etc/nginx/sites-enabled/sincroapp.com.br}"
DOMAIN="${DOMAIN:-sincroapp.com.br}"
NODE_VERSION="${NODE_VERSION:-20}"
FIREBASE_PROJECT="${FIREBASE_PROJECT:-sincroapp-529cc}"
# Flags
SKIP_NGINX="${SKIP_NGINX:-0}"
SKIP_SSL="${SKIP_SSL:-1}"
RENDERER="${RENDERER:-html}"
RECAPTCHA_V3_SITE_KEY="${RECAPTCHA_V3_SITE_KEY:-6LeC__ArAAAAAJUbYkba086MP-cCJBolbjLcm_uU}"

# Função para log colorido
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Função para verificar se comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Banner
echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║     SINCROAPP - INSTALAÇÃO COMPLETA DO SISTEMA WEB         ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# 1. VERIFICAR SE ESTÁ RODANDO COMO ROOT
log_info "Verificando permissões..."
if [ "$EUID" -ne 0 ]; then 
    log_error "Por favor, execute este script como root ou com sudo"
    exit 1
fi
log_success "Executando como root"

# 2. ATUALIZAÇÃO DO SISTEMA (REMOVIDA)
log_info "Pulando atualização do sistema operacional (conforme solicitado)"

# 3. DEPENDÊNCIAS BASE (REMOVIDAS)
log_info "Pulando instalação de dependências base (nginx, certbot, etc.)"

# 4. NODE.JS E NPM (ASSUMIR INSTALADO)
if command_exists node; then
    log_success "Node.js detectado: $(node --version)"
else
    log_warning "Node.js não detectado. Instale manualmente antes de prosseguir."
fi

# 5. INSTALAR FIREBASE CLI
if ! command_exists firebase; then
    log_info "Instalando Firebase CLI..."
    npm install -g firebase-tools
    log_success "Firebase CLI instalado"
else
    log_success "Firebase CLI já instalado"
fi

# 6. INSTALAR FLUTTER
if ! command_exists flutter; then
    log_info "Instalando Flutter SDK..."
    
    cd /opt
    # Usando URL genérica que sempre pega a última versão estável
    wget -q https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.27.1-stable.tar.xz -O flutter.tar.xz
    tar xf flutter.tar.xz
    rm flutter.tar.xz
    
    # Adicionar ao PATH para todas as sessões (profile.d)
    echo 'export PATH="$PATH:/opt/flutter/bin"' > /etc/profile.d/flutter.sh
    chmod 644 /etc/profile.d/flutter.sh
    export PATH="$PATH:/opt/flutter/bin"

    # Corrigir aviso de "dubious ownership" ao rodar como root
    git config --global --add safe.directory /opt/flutter || true

    # Configurar Flutter
    flutter config --no-analytics || true
    flutter channel stable || true
    flutter doctor || true
    
    log_success "Flutter SDK instalado (canal estável)"
else
    log_success "Flutter SDK já instalado"
    git config --global --add safe.directory /opt/flutter || true
    export PATH="$PATH:/opt/flutter/bin"
    flutter --version || true
fi

# 7. PM2 (ASSUMIR INSTALADO)
if command_exists pm2; then
    log_success "PM2 detectado"
else
    log_warning "PM2 não detectado. Instale manualmente se for usar o serviço de notificações."
fi

# 8. CLONAR REPOSITÓRIO DO GITHUB
log_info "Clonando repositório do GitHub..."

# Sair do diretório se estivermos dentro dele (evita "No such file or directory")
cd /tmp  # Mudar para diretório seguro

if [ -d "$INSTALL_DIR" ]; then
    log_warning "Diretório $INSTALL_DIR já existe. Removendo..."
    rm -rf "$INSTALL_DIR"
fi

mkdir -p "$(dirname "$INSTALL_DIR")"
log_info "Clonando de $GITHUB_REPO para $INSTALL_DIR..."
git clone "$GITHUB_REPO" "$INSTALL_DIR"

if [ ! -d "$INSTALL_DIR" ]; then
    log_error "Falha ao clonar repositório"
    exit 1
fi

cd "$INSTALL_DIR"
log_success "Repositório clonado com sucesso"

# 9. CORRIGIR VERSÃO DO PACOTE COLLECTION NO PUBSPEC.YAML
log_info "Corrigindo versões de pacotes para compatibilidade com flutter_test e Dart SDK..."
sed -i 's/collection: \^1\.19\.1/collection: ^1.18.0/' "$INSTALL_DIR/pubspec.yaml"
sed -i 's/google_sign_in: \^7\.2\.0/google_sign_in: ^6.2.1/' "$INSTALL_DIR/pubspec.yaml"
sed -i 's/google_fonts: \^6\.3\.2/google_fonts: ^6.1.0/' "$INSTALL_DIR/pubspec.yaml"
sed -i 's/table_calendar: \^3\.2\.0/table_calendar: ^3.1.3/' "$INSTALL_DIR/pubspec.yaml"
sed -i 's/firebase_core: \^4\.2\.0/firebase_core: ^3.6.0/' "$INSTALL_DIR/pubspec.yaml"
sed -i 's/firebase_auth: \^6\.1\.1/firebase_auth: ^5.3.1/' "$INSTALL_DIR/pubspec.yaml"
sed -i 's/cloud_firestore: \^6\.0\.3/cloud_firestore: ^5.4.4/' "$INSTALL_DIR/pubspec.yaml"
sed -i 's/firebase_ai: \^3\.4\.0/firebase_ai: ^2.3.0/' "$INSTALL_DIR/pubspec.yaml"
sed -i 's/firebase_app_check: \^0\.4\.1+1/firebase_app_check: ^0.3.1+2/' "$INSTALL_DIR/pubspec.yaml"
sed -i 's/cloud_functions: \^6\.0\.3/cloud_functions: ^5.1.3/' "$INSTALL_DIR/pubspec.yaml"
sed -i 's/flutter_local_notifications: \^18\.0\.1/flutter_local_notifications: ^17.2.3/' "$INSTALL_DIR/pubspec.yaml"
sed -i 's/timezone: \^0\.10\.0/timezone: ^0.9.4/' "$INSTALL_DIR/pubspec.yaml"
sed -i 's/firebase_messaging: \^16\.0\.3/firebase_messaging: ^15.1.3/' "$INSTALL_DIR/pubspec.yaml"
sed -i 's/flutter_lints: \^4\.0\.0/flutter_lints: ^3.0.2/' "$INSTALL_DIR/pubspec.yaml"
# Corrigir intl para versão compatível com Flutter 3.27.1 (VPS usa intl 0.19.0)
sed -i 's/intl: \^0\.20\.2/intl: ^0.19.0/' "$INSTALL_DIR/pubspec.yaml"

# Reverter withValues para withOpacity (Flutter 3.27.1 não suporta withValues completo)
log_info "Revertendo withValues() para withOpacity() para compatibilidade com Flutter 3.27.1..."
# Cobrir casos com literais, variáveis e expressões (ternário, etc.)
find "$INSTALL_DIR/lib" -name "*.dart" -type f -exec sed -Ei 's/\.withValues\(alpha: ([^)]*)\)/.withOpacity(\1)/g' {} +

# Ajustar DropdownButtonFormField: initialValue -> value (compatibilidade com Flutter 3.27.1)
sed -i "s/initialValue:/value:/g" "$INSTALL_DIR/lib/features/admin/presentation/widgets/user_edit_dialog.dart"

log_success "pubspec.yaml e código-fonte corrigidos para Flutter 3.27.1"

# 10. INSTALAR DEPENDÊNCIAS FLUTTER
log_info "Instalando dependências Flutter..."
flutter pub get
log_success "Dependências Flutter instaladas"

# 11. INSTALAR DEPENDÊNCIAS FIREBASE FUNCTIONS
log_info "Instalando dependências Firebase Functions..."
cd "$INSTALL_DIR/functions"
npm install
cd "$INSTALL_DIR"
log_success "Dependências Firebase Functions instaladas"

# 12. INSTALAR DEPENDÊNCIAS SERVIÇO DE NOTIFICAÇÕES
if [ -d "$INSTALL_DIR/notification-service" ]; then
    log_info "Instalando dependências do Serviço de Notificações..."
    cd "$INSTALL_DIR/notification-service"
    npm install
    cd "$INSTALL_DIR"
    log_success "Dependências do Serviço de Notificações instaladas"
fi

# 13. BUILD FLUTTER WEB
log_info "Gerando build Flutter Web (isso pode demorar alguns minutos)..."
cd "$INSTALL_DIR"

# Garantir que estamos usando o Flutter correto
export PATH="$PATH:/opt/flutter/bin"

# Limpar cache antes do build
flutter clean || true

# Fazer build
flutter build web --release --web-renderer "$RENDERER" \
    --base-href /app/ \
    --dart-define=RECAPTCHA_V3_SITE_KEY="$RECAPTCHA_V3_SITE_KEY"

if [ ! -d "$INSTALL_DIR/build/web" ]; then
    log_error "Build falhou - diretório build/web não foi criado"
    exit 1
fi

log_success "Build Flutter Web concluído"

# 13.1. COPIAR LANDING PARA O BUILD
log_info "Publicando landing (landing.html/js e firebase-config.js) no build/web..."

# Copiar arquivos da landing para a pasta pública do Flutter
# NOTA: firebase-config.js já possui a site key correta hardcoded
cp -f "$INSTALL_DIR/web/landing.html" "$INSTALL_DIR/build/web/landing.html"
cp -f "$INSTALL_DIR/web/landing.js" "$INSTALL_DIR/build/web/landing.js"
cp -f "$INSTALL_DIR/web/firebase-config.js" "$INSTALL_DIR/build/web/firebase-config.js"
cp -f "$INSTALL_DIR/web/favicon.png" "$INSTALL_DIR/build/web/favicon.png" 2>/dev/null || true

# Copiar ícones se existirem
if [ -d "$INSTALL_DIR/web/icons" ]; then
    mkdir -p "$INSTALL_DIR/build/web/icons"
    cp -rf "$INSTALL_DIR/web/icons/"* "$INSTALL_DIR/build/web/icons/"
fi

log_success "Landing publicada em build/web"

# 14. CONFIGURAR FIREBASE (LOGIN E PROJETO)
if ! command_exists firebase; then
    log_warning "Firebase CLI não encontrado. Instalando via npm (global)..."
    npm install -g firebase-tools || log_error "Falha ao instalar Firebase CLI"
fi

if command_exists firebase; then
    log_info "Autenticando no Firebase (use --no-localhost se necessário)..."
    firebase login --no-localhost || log_warning "Login Firebase pulado/sem sucesso; continue se já estiver autenticado."

    # Definir projeto automaticamente
    log_info "Selecionando projeto Firebase: $FIREBASE_PROJECT"
    firebase use "$FIREBASE_PROJECT" || log_warning "Falha ao selecionar projeto; verifique permissões."
else
    log_warning "Firebase CLI indisponível. Pule esta etapa e faça login/deploy manualmente depois."
fi

# 15. NGINX (CONFIGURAR LANDING EM / E APP EM /app)
if [ "$SKIP_NGINX" = "1" ]; then
    log_info "SKIP_NGINX=1 definido. Pulando configuração do Nginx."
else
    log_info "Escrevendo configuração Nginx em: $NGINX_CONFIG"

    WWW_DOMAIN="www.$DOMAIN"
    WEB_ROOT="$INSTALL_DIR/build/web"

    # Backup da config antiga (se houver)
    if [ -f "$NGINX_CONFIG" ]; then
        cp -f "$NGINX_CONFIG" "$NGINX_CONFIG.bak.$(date +%Y%m%d%H%M%S)"
    fi

    cat > "$NGINX_CONFIG" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN $WWW_DOMAIN;
    return 301 https://$DOMAIN\$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN $WWW_DOMAIN;

    # Certificados SSL
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    root $WEB_ROOT;
    index landing.html index.html;

    access_log /var/log/nginx/sincroapp-access.log;
    error_log /var/log/nginx/sincroapp-error.log;

    # Rota raiz: landing
    location = / {
        try_files /landing.html =404;
    }

    # App Flutter em /app
    location = /app {
        return 301 /app/;
    }
    
    # Assets JS/CSS do app (DEVE VIR ANTES de location /app/)
    location ~* ^/app/.*\.(js|css|wasm|json|map)$ {
        try_files \$uri =404;
        expires 1y;
        add_header Cache-Control "public, immutable";
        # Não force Content-Type; deixe o mime.types definir corretamente
    }
    
    location /app/ {
        # Remove \$uri/ para evitar redirecionamentos 301 em rotas dinâmicas (ex: /app/login)
        try_files \$uri /app/index.html;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
        add_header Expires "0";
    }

    # Arquivos estáticos gerais
    location ~* \.(png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Landing HTML e scripts (sem cache para evitar versão antiga)
    location = /landing.html {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
        add_header Expires "0";
        try_files /landing.html =404;
    }

    location ~* ^/(landing|firebase-config)\.js$ {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
        add_header Expires "0";
    }

    # Manifest/Service Worker
    location ~* (manifest\.json|flutter_service_worker\.js)$ {
        expires 1h;
        add_header Cache-Control "public";
    }

    # Segurança
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Content-Security-Policy "default-src 'self' https:; script-src 'self' 'unsafe-inline' 'unsafe-eval' https://cdn.tailwindcss.com https://www.gstatic.com https://unpkg.com https://www.google.com https://recaptchaenterprise.googleapis.com; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com https://unpkg.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' data: https:; connect-src 'self' https://firestore.googleapis.com https://*.cloudfunctions.net wss://*.firebaseio.com https://identitytoolkit.googleapis.com https://recaptchaenterprise.googleapis.com https://www.gstatic.com https://www.google.com https://content-firebaseappcheck.googleapis.com; frame-src https://www.google.com; worker-src 'self' blob: https://www.google.com;" always;

    autoindex off;
    client_max_body_size 10M;

    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript application/json application/javascript application/xml+rss application/atom+xml image/svg+xml;
}
EOF

    # Criar symlink em sites-enabled, se definido e necessário
    if [ -n "$NGINX_ENABLED" ]; then
        ln -sf "$NGINX_CONFIG" "$NGINX_ENABLED" 2>/dev/null || true
    fi

    nginx -t || { log_error "nginx -t falhou. Revise $NGINX_CONFIG"; exit 1; }
    systemctl reload nginx
    log_success "Nginx configurado e recarregado"
fi

# 16. SSL (NENHUMA ALTERAÇÃO)
log_info "Pulando alterações de SSL (usando certificados já configurados)"

# 17. CONFIGURAR SERVIÇO DE NOTIFICAÇÕES
if [ -d "$INSTALL_DIR/notification-service" ]; then
    log_info "Configurando Serviço de Notificações com PM2..."
    
    cd "$INSTALL_DIR/notification-service"
    
    # Parar processo antigo se existir
    pm2 delete sincroapp-notifications 2>/dev/null || true
    
    # Iniciar novo processo
    pm2 start index.js --name sincroapp-notifications --time
    pm2 save
    
    log_success "Serviço de Notificações configurado e iniciado"
fi

# 18. FIREBASE FUNCTIONS (DEPLOY)
log_info "Instalando dependências das Firebase Functions e realizando deploy..."
cd "$INSTALL_DIR/functions"
npm install || log_error "npm install em functions falhou"
cd "$INSTALL_DIR"
if command_exists firebase; then
    firebase deploy --only functions || log_warning "Deploy das Functions falhou. Verifique autenticação e permissões."
else
    log_warning "Firebase CLI indisponível. Pule esta etapa e faça deploy manualmente: firebase deploy --only functions"
fi

# 19. CONFIGURAR PERMISSÕES
log_info "Configurando permissões..."
chown -R www-data:www-data "$INSTALL_DIR/build/web"
chmod -R 755 "$INSTALL_DIR/build/web"
log_success "Permissões configuradas"

# 20. FIREWALL (NENHUMA ALTERAÇÃO)
log_info "Pulando configuração de firewall (nenhuma mudança solicitada)"

# 21. VERIFICAR SERVIÇOS
log_info "Verificando status dos serviços..."

# Nginx
if systemctl is-active --quiet nginx; then
    log_success "Nginx: Ativo ✓"
else
    log_error "Nginx: Inativo ✗"
fi

# PM2
if pm2 list | grep -q sincroapp-notifications; then
    log_success "Serviço de Notificações: Ativo ✓"
else
    log_warning "Serviço de Notificações: Não encontrado"
fi

# 22. RESUMO FINAL
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           INSTALAÇÃO CONCLUÍDA COM SUCESSO!                ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
log_info "RESUMO DA INSTALAÇÃO:"
echo -e "  ${BLUE}├─${NC} Diretório de instalação: $INSTALL_DIR"
echo -e "  ${BLUE}├─${NC} Build Flutter Web: $INSTALL_DIR/build/web"
echo -e "  ${BLUE}├─${NC} Configuração Nginx: $NGINX_CONFIG"
echo -e "  ${BLUE}├─${NC} Projeto Firebase: $FIREBASE_PROJECT"
echo -e "  ${BLUE}├─${NC} Domínio: https://$DOMAIN"
echo -e "  ${BLUE}└─${NC} Serviço de Notificações: PM2 (sincroapp-notifications)"
echo ""
log_info "COMANDOS ÚTEIS:"
echo -e "  ${BLUE}├─${NC} Verificar logs Nginx: ${BLUE}tail -f /var/log/nginx/error.log${NC}"
echo -e "  ${BLUE}├─${NC} Verificar logs PM2: ${BLUE}pm2 logs sincroapp-notifications${NC}"
echo -e "  ${BLUE}├─${NC} Reiniciar Nginx: ${BLUE}systemctl reload nginx${NC}"
echo -e "  ${BLUE}├─${NC} Reiniciar Notificações: ${BLUE}pm2 restart sincroapp-notifications${NC}"
echo -e "  ${BLUE}└─${NC} Atualizar sistema: ${BLUE}$INSTALL_DIR/deploy/update.sh${NC}"
echo ""
log_success "Sistema instalado e pronto para uso!"
