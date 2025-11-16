#!/bin/bash

###############################################################################
# Script de Atualização - SincroApp Flutter Web
# Autor: Sistema de Deploy Automatizado
# Data: 2025-11-16
# Descrição: Atualiza o sistema já instalado com nova versão do código
###############################################################################

set -e  # Encerra o script em caso de erro

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurações
INSTALL_DIR="/var/www/webapp/sincroapp_flutter"
GITHUB_REPO="https://github.com/gmalickovski/sincroapp_flutter.git"
BACKUP_DIR="/var/backups/sincroapp_flutter"
BRANCH="${1:-main}"  # Branch padrão: main

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

# Banner
echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║        SINCROAPP - ATUALIZAÇÃO DO SISTEMA WEB              ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# 1. VERIFICAR SE ESTÁ RODANDO COMO ROOT
log_info "Verificando permissões..."
if [ "$EUID" -ne 0 ]; then 
    log_error "Por favor, execute este script como root ou com sudo"
    exit 1
fi
log_success "Executando como root"

# 2. VERIFICAR SE O DIRETÓRIO EXISTE
if [ ! -d "$INSTALL_DIR" ]; then
    log_error "Diretório $INSTALL_DIR não encontrado. Execute o script de instalação primeiro."
    exit 1
fi

# 3. CRIAR BACKUP
log_info "Criando backup da versão atual..."
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="$BACKUP_DIR/backup_$TIMESTAMP"

mkdir -p "$BACKUP_DIR"

# Backup do código
cp -r "$INSTALL_DIR" "$BACKUP_PATH"

# Backup da configuração Nginx
cp /etc/nginx/sites-available/sincroapp.com.br "$BACKUP_PATH/nginx_config.bak" 2>/dev/null || true

log_success "Backup criado em: $BACKUP_PATH"

# 4. PARAR SERVIÇOS
log_info "Parando serviços..."

# Parar PM2 (Serviço de Notificações)
if pm2 list | grep -q sincroapp-notifications; then
    pm2 stop sincroapp-notifications
    log_success "Serviço de Notificações parado"
fi

# 5. ATUALIZAR CÓDIGO DO GITHUB
log_info "Atualizando código do GitHub (branch: $BRANCH)..."
cd "$INSTALL_DIR"

# Salvar alterações locais (se houver)
git stash

# Atualizar do repositório
git fetch origin
git checkout "$BRANCH"
git pull origin "$BRANCH"

log_success "Código atualizado do GitHub"

# 6. ATUALIZAR DEPENDÊNCIAS FLUTTER
log_info "Atualizando dependências Flutter..."
# Corrigir possível aviso de propriedade ao rodar como root
git config --global --add safe.directory /opt/flutter || true
if [ -f /etc/profile.d/flutter.sh ]; then
    . /etc/profile.d/flutter.sh || true
fi
export PATH="$PATH:/opt/flutter/bin"
flutter channel stable || true
flutter upgrade || true
flutter pub get
log_success "Dependências Flutter atualizadas"

# 7. ATUALIZAR DEPENDÊNCIAS FIREBASE FUNCTIONS
log_info "Atualizando dependências Firebase Functions..."
cd "$INSTALL_DIR/functions"
npm install
cd "$INSTALL_DIR"
log_success "Dependências Firebase Functions atualizadas"

# 8. ATUALIZAR DEPENDÊNCIAS SERVIÇO DE NOTIFICAÇÕES
if [ -d "$INSTALL_DIR/notification-service" ]; then
    log_info "Atualizando dependências do Serviço de Notificações..."
    cd "$INSTALL_DIR/notification-service"
    npm install
    cd "$INSTALL_DIR"
    log_success "Dependências do Serviço de Notificações atualizadas"
fi

# 9. LIMPAR BUILD ANTERIOR
log_info "Limpando build anterior..."
flutter clean
log_success "Build anterior removido"

# 10. GERAR NOVO BUILD
log_info "Gerando novo build Flutter Web (isso pode demorar alguns minutos)..."
flutter build web --release --web-renderer html
log_success "Novo build gerado"

# 11. CONFIGURAR PERMISSÕES
log_info "Configurando permissões..."
chown -R www-data:www-data "$INSTALL_DIR/build/web"
chmod -R 755 "$INSTALL_DIR/build/web"
log_success "Permissões configuradas"

# 12. LIMPAR CACHE NGINX
log_info "Limpando cache do navegador (força reload)..."
# Adiciona timestamp ao index.html para forçar reload
CACHE_BUSTER="?v=$TIMESTAMP"
log_info "Cache buster: $CACHE_BUSTER"

# 13. TESTAR CONFIGURAÇÃO NGINX
log_info "Testando configuração Nginx..."
nginx -t
if [ $? -eq 0 ]; then
    log_success "Configuração Nginx válida"
else
    log_error "Erro na configuração do Nginx"
    log_warning "Restaurando backup..."
    rm -rf "$INSTALL_DIR"
    cp -r "$BACKUP_PATH" "$INSTALL_DIR"
    exit 1
fi

# 14. RECARREGAR NGINX
log_info "Recarregando Nginx..."
systemctl reload nginx
log_success "Nginx recarregado"

# 15. REINICIAR SERVIÇO DE NOTIFICAÇÕES
if [ -d "$INSTALL_DIR/notification-service" ]; then
    log_info "Reiniciando Serviço de Notificações..."
    cd "$INSTALL_DIR/notification-service"
    
    # Parar e remover processo antigo
    pm2 delete sincroapp-notifications 2>/dev/null || true
    
    # Iniciar novo processo
    pm2 start index.js --name sincroapp-notifications --time
    pm2 save
    
    log_success "Serviço de Notificações reiniciado"
fi

# 16. DEPLOY FIREBASE FUNCTIONS (OPCIONAL)
log_info "Deseja fazer deploy das Firebase Functions? (s/N)"
read -t 10 -r DEPLOY_FUNCTIONS || DEPLOY_FUNCTIONS="n"

if [[ $DEPLOY_FUNCTIONS =~ ^[Ss]$ ]]; then
    log_info "Fazendo deploy das Firebase Functions..."
    cd "$INSTALL_DIR"
    firebase deploy --only functions
    log_success "Firebase Functions atualizadas"
else
    log_warning "Deploy das Functions pulado. Execute manualmente se necessário:"
    log_warning "  cd $INSTALL_DIR && firebase deploy --only functions"
fi

# 17. VERIFICAR SERVIÇOS
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

# 18. TESTE DE SAÚDE
log_info "Executando teste de saúde..."
HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}\n" https://sincroapp.com.br)

if [ "$HTTP_STATUS" -eq 200 ] || [ "$HTTP_STATUS" -eq 301 ] || [ "$HTTP_STATUS" -eq 302 ]; then
    log_success "Aplicação respondendo corretamente (HTTP $HTTP_STATUS)"
else
    log_warning "Aplicação retornou HTTP $HTTP_STATUS - verifique os logs"
fi

# 19. LIMPAR BACKUPS ANTIGOS (MANTER APENAS 5 MAIS RECENTES)
log_info "Limpando backups antigos..."
cd "$BACKUP_DIR"
ls -t | tail -n +6 | xargs -r rm -rf
BACKUP_COUNT=$(ls -1 | wc -l)
log_success "Mantendo $BACKUP_COUNT backups mais recentes"

# 20. RESUMO FINAL
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          ATUALIZAÇÃO CONCLUÍDA COM SUCESSO!                ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
log_info "RESUMO DA ATUALIZAÇÃO:"
echo -e "  ${BLUE}├─${NC} Branch atualizado: $BRANCH"
echo -e "  ${BLUE}├─${NC} Versão do build: $TIMESTAMP"
echo -e "  ${BLUE}├─${NC} Backup salvo em: $BACKUP_PATH"
echo -e "  ${BLUE}├─${NC} Status HTTP: $HTTP_STATUS"
echo -e "  ${BLUE}└─${NC} Domínio: https://sincroapp.com.br"
echo ""
log_info "COMANDOS ÚTEIS:"
echo -e "  ${BLUE}├─${NC} Verificar logs Nginx: ${BLUE}tail -f /var/log/nginx/error.log${NC}"
echo -e "  ${BLUE}├─${NC} Verificar logs PM2: ${BLUE}pm2 logs sincroapp-notifications${NC}"
echo -e "  ${BLUE}├─${NC} Reverter para backup: ${BLUE}cp -r $BACKUP_PATH $INSTALL_DIR${NC}"
echo -e "  ${BLUE}└─${NC} Monitorar serviços: ${BLUE}pm2 monit${NC}"
echo ""

# 21. INFORMAÇÕES DE ROLLBACK
log_warning "EM CASO DE PROBLEMAS:"
echo -e "  ${YELLOW}1.${NC} Para reverter para o backup:"
echo -e "     ${BLUE}sudo rm -rf $INSTALL_DIR${NC}"
echo -e "     ${BLUE}sudo cp -r $BACKUP_PATH $INSTALL_DIR${NC}"
echo -e "     ${BLUE}sudo systemctl reload nginx${NC}"
echo -e "     ${BLUE}sudo pm2 restart sincroapp-notifications${NC}"
echo ""

log_success "Atualização concluída! Acesse https://sincroapp.com.br para verificar"
