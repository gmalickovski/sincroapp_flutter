#!/bin/bash

###############################################################################
# Script de Quick Deploy - SincroApp Flutter Web
# Autor: Sistema de Deploy Automatizado  
# Data: 2025-11-16
# Descrição: Script rápido para deploy local-para-servidor
###############################################################################

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configurações (AJUSTE CONFORME SEU AMBIENTE)
SERVER_USER="root"
SERVER_HOST="seu-servidor.com"  # ALTERE AQUI
SERVER_PATH="/var/www/webapp/sincroapp_flutter"
LOCAL_PATH="$(pwd)"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║         SINCROAPP - QUICK DEPLOY (LOCAL → SERVIDOR)        ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Verificar se estamos no diretório correto
if [ ! -f "pubspec.yaml" ]; then
    log_error "Execute este script no diretório raiz do projeto Flutter"
    exit 1
fi

# Menu de opções
echo "Selecione o tipo de deploy:"
echo "1) Deploy completo (código + build + restart)"
echo "2) Deploy apenas código (sem rebuild)"
echo "3) Deploy apenas Flutter Web"
echo "4) Deploy apenas Functions"
echo "5) Deploy apenas Notification Service"
echo ""
read -p "Opção [1-5]: " DEPLOY_OPTION

case $DEPLOY_OPTION in
    1)
        log_info "Deploy completo selecionado"
        DEPLOY_TYPE="full"
        ;;
    2)
        log_info "Deploy apenas código selecionado"
        DEPLOY_TYPE="code"
        ;;
    3)
        log_info "Deploy apenas Flutter Web selecionado"
        DEPLOY_TYPE="web"
        ;;
    4)
        log_info "Deploy apenas Functions selecionado"
        DEPLOY_TYPE="functions"
        ;;
    5)
        log_info "Deploy apenas Notification Service selecionado"
        DEPLOY_TYPE="notifications"
        ;;
    *)
        log_error "Opção inválida"
        exit 1
        ;;
esac

# Função para deploy completo
deploy_full() {
    log_info "Iniciando deploy completo..."
    
    # 1. Build local
    log_info "Gerando build Flutter Web..."
    flutter build web --release --web-renderer html
    
    # 2. Criar pacote para envio
    log_info "Criando pacote de deploy..."
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    DEPLOY_PACKAGE="/tmp/sincroapp_deploy_$TIMESTAMP.tar.gz"
    
    tar -czf "$DEPLOY_PACKAGE" \
        --exclude='node_modules' \
        --exclude='.git' \
        --exclude='build/ios' \
        --exclude='build/android' \
        --exclude='build/macos' \
        --exclude='build/linux' \
        --exclude='build/windows' \
        .
    
    log_success "Pacote criado: $DEPLOY_PACKAGE"
    
    # 3. Enviar para servidor
    log_info "Enviando pacote para servidor..."
    scp "$DEPLOY_PACKAGE" "$SERVER_USER@$SERVER_HOST:/tmp/"
    
    # 4. Executar no servidor
    log_info "Executando deploy no servidor..."
    ssh "$SERVER_USER@$SERVER_HOST" << ENDSSH
        set -e
        
        # Backup
        BACKUP_DIR="/var/backups/sincroapp_flutter/backup_$TIMESTAMP"
        mkdir -p "\$BACKUP_DIR"
        cp -r "$SERVER_PATH" "\$BACKUP_DIR"
        
        # Extrair novo código
        cd "$SERVER_PATH"
        tar -xzf "/tmp/sincroapp_deploy_$TIMESTAMP.tar.gz"
        
        # Instalar dependências
        flutter pub get
        cd functions && npm install && cd ..
        if [ -d "notification-service" ]; then
            cd notification-service && npm install && cd ..
        fi
        
        # Configurar permissões
        chown -R www-data:www-data build/web
        chmod -R 755 build/web
        
        # Reiniciar serviços
        systemctl reload nginx
        pm2 restart sincroapp-notifications || true
        
        # Limpar
        rm "/tmp/sincroapp_deploy_$TIMESTAMP.tar.gz"
        
        echo "Deploy completo concluído!"
ENDSSH
    
    # 5. Limpar local
    rm "$DEPLOY_PACKAGE"
    
    log_success "Deploy completo finalizado!"
}

# Função para deploy apenas código
deploy_code() {
    log_info "Sincronizando código com servidor..."
    
    rsync -avz --delete \
        --exclude='node_modules' \
        --exclude='.git' \
        --exclude='build/' \
        --exclude='.dart_tool/' \
        "$LOCAL_PATH/" "$SERVER_USER@$SERVER_HOST:$SERVER_PATH/"
    
    log_success "Código sincronizado!"
}

# Função para deploy apenas web
deploy_web() {
    log_info "Deploy Flutter Web..."
    
    # Build local
    flutter build web --release --web-renderer html
    
    # Enviar apenas build/web
    rsync -avz --delete \
        "$LOCAL_PATH/build/web/" "$SERVER_USER@$SERVER_HOST:$SERVER_PATH/build/web/"
    
    # Reiniciar Nginx
    ssh "$SERVER_USER@$SERVER_HOST" "systemctl reload nginx"
    
    log_success "Flutter Web atualizado!"
}

# Função para deploy apenas functions
deploy_functions() {
    log_info "Deploy Firebase Functions..."
    
    cd functions
    firebase deploy --only functions
    cd ..
    
    log_success "Functions atualizadas!"
}

# Função para deploy apenas notifications
deploy_notifications() {
    log_info "Deploy Notification Service..."
    
    # Enviar código do notification-service
    rsync -avz --delete \
        "$LOCAL_PATH/notification-service/" "$SERVER_USER@$SERVER_HOST:$SERVER_PATH/notification-service/"
    
    # Reinstalar e reiniciar
    ssh "$SERVER_USER@$SERVER_HOST" << ENDSSH
        cd "$SERVER_PATH/notification-service"
        npm install
        pm2 restart sincroapp-notifications
ENDSSH
    
    log_success "Notification Service atualizado!"
}

# Executar deploy conforme opção
case $DEPLOY_TYPE in
    full)
        deploy_full
        ;;
    code)
        deploy_code
        ;;
    web)
        deploy_web
        ;;
    functions)
        deploy_functions
        ;;
    notifications)
        deploy_notifications
        ;;
esac

# Teste de saúde
log_info "Verificando saúde da aplicação..."
sleep 3
HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}\n" https://sincroapp.com.br || echo "000")

if [ "$HTTP_STATUS" -eq 200 ] || [ "$HTTP_STATUS" -eq 301 ]; then
    log_success "Aplicação respondendo (HTTP $HTTP_STATUS) ✓"
else
    log_error "Aplicação não está respondendo corretamente (HTTP $HTTP_STATUS)"
fi

echo ""
log_success "Deploy concluído! Acesse: https://sincroapp.com.br"
