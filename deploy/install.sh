#!/bin/bash

###############################################################################
# Script de Instalação Completa - SincroApp Flutter Web + Supabase 
# Autor: Equipe Sincro (Atualizado)
# Data: 2025-12-31
# Descrição: Instala e configura todo o sistema (Web + Notificações + Functions)
###############################################################################

set -e  # Encerra o script em caso de erro

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ==============================================================================
# CONFIGURAÇÕES (Edite se necessário ou passe como variáveis de ambiente)
# ==============================================================================

# Diretórios
INSTALL_DIR="${INSTALL_DIR:-/var/www/webapp/sincroapp_flutter}"
GITHUB_REPO="${GITHUB_REPO:-https://github.com/gmalickovski/sincroapp_flutter.git}"
SUPABASE_DOCKER_DIR="${SUPABASE_DOCKER_DIR:-/root/supabase}" # Onde está seu docker-compose.yml do Supabase

# Web Server
DOMAIN="${DOMAIN:-sincroapp.com.br}"
NGINX_CONFIG="${NGINX_CONFIG:-/etc/nginx/sites-available/sincroapp.com.br}"

# Recaptcha
RECAPTCHA_V3_SITE_KEY="${RECAPTCHA_V3_SITE_KEY:-6LfPrg8sAAAAAEM0C6vuU0H9qMlXr89zr553zi_B}"

# Logs helpers
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
command_exists() { command -v "$1" >/dev/null 2>&1; }

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      SINCROAPP - INSTALAÇÃO (VERSÃO SUPABASE/VPS)          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"

# 1. VERIFICAR ROOT
if [ "$EUID" -ne 0 ]; then 
    log_error "Execute como root (sudo)"
    exit 1
fi

# 2. DEPENDÊNCIAS DO SISTEMA
log_info "Verificando dependências básicas..."
if ! command_exists node; then log_error "Node.js não encontrado. Instale Node v20+."; exit 1; fi
if ! command_exists flutter; then log_warning "Flutter não encontrado no PATH. Tentando /opt/flutter..."; export PATH="$PATH:/opt/flutter/bin"; fi
if ! command_exists flutter; then log_error "Flutter não encontrado. Instale o Flutter SDK."; exit 1; fi
if ! command_exists pm2; then npm install -g pm2; fi

log_success "Dependências verificadas."

# 3. LIMPEZA E CLONE (CLEAN INSTALL)
log_info "Preparando instalação limpa..."

# Se existir, removemos para garantir zero conflitos
if [ -d "$INSTALL_DIR" ]; then
    log_warning "Removendo instalação anterior em $INSTALL_DIR..."
    rm -rf "$INSTALL_DIR"
fi

mkdir -p "$(dirname "$INSTALL_DIR")"
log_info "Clonando repositório..."
git clone "$GITHUB_REPO" "$INSTALL_DIR"
cd "$INSTALL_DIR"

# 4. CONFIGURAÇÃO PUBSPEC (CORREÇÕES DE COMPATIBILIDADE)
log_info "Ajustando verões no pubspec.yaml para VPS..."
sed -i 's/intl: \^0\.20\.2/intl: ^0.19.0/' pubspec.yaml
# Adicione outros seds específicos se necessário (igual ao script anterior)
sed -i 's/collection: \^1\.19\.1/collection: ^1.18.0/' pubspec.yaml

# 5. INSTALAR DEPENDÊNCIAS FLUTTER E BUILD
log_info "Instalando dependências Flutter..."
flutter pub get

log_info "Gerando BUILD WEB (Release)..."
flutter clean
flutter build web --release \
    --base-href /app/ \
    --dart-define=RECAPTCHA_V3_SITE_KEY="$RECAPTCHA_V3_SITE_KEY"

if [ ! -d "build/web" ]; then
    log_error "Falha no build do Flutter Web."
    exit 1
fi
log_success "Build Flutter Web concluído."

# 6. INSTALAR LANDING PAGE
log_info "Configurando Landing Page..."
cp -f web/landing.html build/web/landing.html
cp -f web/landing.js build/web/landing.js
cp -f web/firebase-config.js build/web/firebase-config.js
cp -f web/favicon.png build/web/favicon.png 2>/dev/null || true
if [ -d "web/icons" ]; then cp -rf web/icons build/web/; fi

# 7. CONFIGURAR SUPABASE FUNCTIONS (DEPLOY LOCAL -> VPS)
log_info "Configurando Supabase Edge Functions..."

if [ -d "$SUPABASE_DOCKER_DIR" ]; then
    DEST_FUNCTIONS="$SUPABASE_DOCKER_DIR/volumes/functions"
    
    # Criar pasta destination se não existir
    mkdir -p "$DEST_FUNCTIONS"
    
    log_info "Copiando funções para $DEST_FUNCTIONS..."
    # Copia todo o conteúdo de supabase/functions do repo para o volume do docker
    cp -r supabase/functions/* "$DEST_FUNCTIONS/"
    
    log_info "Reiniciando container Supabase Functions..."
    cd "$SUPABASE_DOCKER_DIR"
    docker compose restart functions || log_warning "Falha ao reiniciar docker functions. Verifique manualmente."
    cd "$INSTALL_DIR"
    
    log_success "Funções atualizadas no Supabase Local."
else
    log_warning "Diretório do Supabase ($SUPABASE_DOCKER_DIR) não encontrado."
    log_warning "Você precisará copiar a pasta 'supabase/functions' manualmente para seu volume do Docker."
fi

# 8. SERVIÇO DE NOTIFICAÇÕES (MIGRADO)
log_info "Configurando Serviço de Notificações (PM2)..."
if [ -d "notification-service" ]; then
    cd notification-service
    
    # Instalar deps
    npm install
    
    # Verificar .env (O usuário precisa configurar isso!)
    if [ ! -f ".env" ]; then
        log_warning "Arquivo .env não encontrado em notification-service."
        echo "SUPABASE_URL=https://supabase.studiomlk.com.br" > .env
        echo "SUPABASE_SERVICE_ROLE_KEY=SUA_KEY_AQUI" >> .env
        log_warning "Criado .env de exemplo. EDITE COM SUA SERVICE KEY!"
    fi
    
    # Reiniciar PM2
    pm2 delete sincroapp-notifications 2>/dev/null || true
    pm2 start index.js --name sincroapp-notifications --time
    pm2 save
    
    cd ..
    log_success "Notification Service iniciado."
fi

# 9. NGINX (CONFIGURAÇÃO)
log_info "Configurando Nginx..."
# (Mantendo a configuração otimizada do script anterior)
cat > "$NGINX_CONFIG" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN www.$DOMAIN;
    return 301 https://$DOMAIN\$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN www.$DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    root $INSTALL_DIR/build/web;
    index landing.html index.html;

    # Landing Page na Raiz
    location = / {
        try_files /landing.html =404;
    }

    # App Flutter em /app
    location = /app {
        return 301 /app/;
    }

    # Assets do Flutter
    location ~ ^/app/(.+)\.(js|css|wasm|json|map)/?\$ {
        try_files /\$1.\$2 =404;
    }
    
    location ^~ /app/assets/ { alias $INSTALL_DIR/build/web/assets/; }
    location ^~ /app/icons/ { alias $INSTALL_DIR/build/web/icons/; }

    # SPA Fallback para rotas do Flutter
    location /app/ {
        try_files \$uri /index.html;
    }
    
    # Landing assets
    location / {
        try_files \$uri =404;
    }
}
EOF

ln -sf "$NGINX_CONFIG" "/etc/nginx/sites-enabled/" 2>/dev/null || true
nginx -t && systemctl reload nginx

# 10. PERMISSÕES FINAIS
chown -R www-data:www-data "$INSTALL_DIR/build/web"
chmod -R 755 "$INSTALL_DIR/build/web"

echo ""
log_success "INSTALAÇÃO CONCLUÍDA!"
echo "Verifique se o .env do notification-service está com a KEY correta."
