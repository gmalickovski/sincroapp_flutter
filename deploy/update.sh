#!/bin/bash

###############################################################################
# Script de Atualização - SincroApp (Supabase Edition)
# Data: 2025-12-31
###############################################################################

set -e

# Configurações
INSTALL_DIR="${INSTALL_DIR:-/var/www/webapp/sincroapp_flutter}"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/sincroapp_flutter}"
SUPABASE_DOCKER_DIR="${SUPABASE_DOCKER_DIR:-/root/supabase}" 
BRANCH="${BRANCH:-${1:-main}}"

# Logs
log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $1"; }

log_info "Iniciando atualização (Branch: $BRANCH)..."

# 1. VERIFICAR INSTALAÇÃO
if [ ! -d "$INSTALL_DIR" ]; then
    log_error "Diretório não encontrado. Execute install.sh primeiro."
    exit 1
fi

# 2. BACKUP
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="$BACKUP_DIR/backup_$TIMESTAMP"
log_info "Criando backup em $BACKUP_PATH..."
mkdir -p "$BACKUP_DIR"
cp -r "$INSTALL_DIR" "$BACKUP_PATH"

# 3. ATUALIZAR CÓDIGO (GIT)
cd "$INSTALL_DIR"
git stash
git fetch origin
git checkout "$BRANCH"
git pull origin "$BRANCH"
log_success "Git pull concluído."

# 4. CORREÇÕES PUBSPEC (Compatibilidade VPS)
sed -i 's/intl: \^0\.20\.2/intl: ^0.19.0/' pubspec.yaml
sed -i 's/collection: \^1\.19\.1/collection: ^1.18.0/' pubspec.yaml

# 5. ATUALIZAR E BUILDAR FLUTTER
log_info "Atualizando Flutter e gerando Build..."
flutter pub get
flutter clean
flutter build web --release --base-href /app/

# Publicar Landing Page no Build
cp -f web/landing.html build/web/landing.html
cp -f web/landing.js build/web/landing.js
cp -f web/firebase-config.js build/web/firebase-config.js
cp -f web/favicon.png build/web/favicon.png 2>/dev/null || true

# Permissões
chown -R www-data:www-data build/web
chmod -R 755 build/web

# 6. ATUALIZAR SUPABASE FUNCTIONS
log_info "Atualizando Supabase Functions..."
if [ -d "$SUPABASE_DOCKER_DIR" ]; then
    cp -r supabase/functions/* "$SUPABASE_DOCKER_DIR/volumes/functions/"
    
    cd "$SUPABASE_DOCKER_DIR"
    docker compose restart functions
    cd "$INSTALL_DIR"
    log_success "Container Functions reiniciado."
else
    log_info "Pasta do Supabase Docker não encontrada. Pule se não usar self-hosted functions localmente."
fi

# 7. ATUALIZAR NOTIFICATION SERVICE
if [ -d "notification-service" ]; then
    log_info "Atualizando Notification Service..."
    cd notification-service
    npm install
    pm2 restart sincroapp-notifications
    cd ..
fi

# 8. RELOAD NGINX
log_info "Recarregando Nginx..."
systemctl reload nginx

log_success "ATUALIZAÇÃO CONCLUÍDA! Versão: $TIMESTAMP"
log_info "Se algo quebrou, reverta usando: cp -r $BACKUP_PATH $INSTALL_DIR"
