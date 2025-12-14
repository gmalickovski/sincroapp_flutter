#!/bin/bash

###############################################################################
# Script de Atualização - SincroApp Flutter Web
# Autor: Sistema de Deploy Automatizado
# Data: 2025-11-16 (Atualizado para Backend API)
# Descrição: Atualiza o sistema já instalado com nova versão do código
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
BACKUP_DIR="${BACKUP_DIR:-/var/backups/sincroapp_flutter}"
BRANCH="${BRANCH:-${1:-main}}"  # Branch padrão: main
DOMAIN="${DOMAIN:-sincroapp.com.br}"
RENDERER="${RENDERER:-html}"   # html | canvaskit
AUTO_DEPLOY_FUNCTIONS="${AUTO_DEPLOY_FUNCTIONS:-0}" # 1 para deploy automático das functions
RECAPTCHA_V3_SITE_KEY="${RECAPTCHA_V3_SITE_KEY:-6LfPrg8sAAAAAEM0C6vuU0H9qMlXr89zr553zi_B}"

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

# Parar PM2 (Novo Backend API)
# Parar PM2 (Novo Backend API)
# Parar PM2 (Novo Backend API)
log_info "Parando Backend API..."
# Migração: Parar e remover nome antigo se existir
pm2 delete sincro-backend 2>/dev/null || true
# Parar nome novo se existir
pm2 stop sincroapp-backend 2>/dev/null || true

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

# 6. CORRIGIR VERSÃO DO PACOTE COLLECTION NO PUBSPEC.YAML
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

# 7. ATUALIZAR DEPENDÊNCIAS FLUTTER (SEM ALTERAR CANAL/SDK)
log_info "Atualizando dependências Flutter (sem upgrade de SDK)..."
# Corrigir possível aviso de propriedade ao rodar como root
git config --global --add safe.directory /opt/flutter || true
if [ -f /etc/profile.d/flutter.sh ]; then
    . /etc/profile.d/flutter.sh || true
fi
export PATH="$PATH:/opt/flutter/bin"
flutter pub get
log_success "Dependências Flutter atualizadas"

# 8. ATUALIZAR DEPENDÊNCIAS FIREBASE FUNCTIONS
log_info "Atualizando dependências Firebase Functions..."
cd "$INSTALL_DIR/functions"
npm install
cd "$INSTALL_DIR"
log_success "Dependências Firebase Functions atualizadas"

# 9. ATUALIZAR DEPENDÊNCIAS SERVIÇO DE NOTIFICAÇÕES
if [ -d "$INSTALL_DIR/notification-service" ]; then
    log_info "Atualizando dependências do Serviço de Notificações..."
    cd "$INSTALL_DIR/notification-service"
    npm install
    cd "$INSTALL_DIR"
    log_success "Dependências do Serviço de Notificações atualizadas"
fi

# 9.1 ATUALIZAR DEPENDÊNCIAS DO BACKEND API (NOVO)
if [ -d "$INSTALL_DIR/server" ]; then
    log_info "Atualizando dependências da API Backend..."
    cd "$INSTALL_DIR/server"
    npm install
    cd "$INSTALL_DIR"
    log_success "Dependências da API Backend atualizadas"
fi

# 10. LIMPAR BUILD ANTERIOR
log_info "Limpando build anterior..."
flutter clean
log_success "Build anterior removido"

# 11. GERAR NOVO BUILD
log_info "Gerando novo build Flutter Web (isso pode demorar alguns minutos)..."
flutter build web --release \
    --base-href /app/ \
    --dart-define=RECAPTCHA_V3_SITE_KEY="$RECAPTCHA_V3_SITE_KEY"

if [ ! -d "$INSTALL_DIR/build/web" ]; then
    log_error "Build falhou - diretório build/web não foi criado"
    exit 1
fi

log_success "Novo build gerado"

# Publicar landing e arquivos públicos adicionais no build (consistência com install.sh)
log_info "Publicando landing (landing.html/js e firebase-config.js) no build/web..."
cp -f "$INSTALL_DIR/web/landing.html" "$INSTALL_DIR/build/web/landing.html" 2>/dev/null || true
cp -f "$INSTALL_DIR/web/landing.js" "$INSTALL_DIR/build/web/landing.js" 2>/dev/null || true
cp -f "$INSTALL_DIR/web/firebase-config.js" "$INSTALL_DIR/build/web/firebase-config.js" 2>/dev/null || true
cp -f "$INSTALL_DIR/web/favicon.png" "$INSTALL_DIR/build/web/favicon.png" 2>/dev/null || true

if [ -d "$INSTALL_DIR/web/icons" ]; then
    mkdir -p "$INSTALL_DIR/build/web/icons"
    cp -rf "$INSTALL_DIR/web/icons/"* "$INSTALL_DIR/build/web/icons/" 2>/dev/null || true
fi
log_success "Landing publicada em build/web"

# 12. CONFIGURAR PERMISSÕES
log_info "Configurando permissões..."
chown -R www-data:www-data "$INSTALL_DIR/build/web"
chmod -R 755 "$INSTALL_DIR/build/web"
log_success "Permissões configuradas"

# 13. LIMPAR CACHE NGINX
log_info "Limpando cache do navegador (força reload)..."
# Adiciona timestamp ao index.html para forçar reload
CACHE_BUSTER="?v=$TIMESTAMP"
log_info "Cache buster: $CACHE_BUSTER"

# 14. TESTAR CONFIGURAÇÃO NGINX
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

# 15. RECARREGAR NGINX
log_info "Recarregando Nginx..."
systemctl reload nginx
log_success "Nginx recarregado"

# 16. REINICIAR SERVIÇO DE NOTIFICAÇÕES
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

# 16.1 REINICIAR BACKEND API (NOVO)
if [ -d "$INSTALL_DIR/server" ]; then
    log_info "Reiniciando Backend API..."
    cd "$INSTALL_DIR/server"
    
    # Parar e remover processo antigo (garante atualização do código)
    pm2 delete sincroapp-backend 2>/dev/null || true
    
    # Iniciar novo processo
    pm2 start index.js --name sincroapp-backend --time
    pm2 save
    
    log_success "Backend API reiniciado"
fi

# 17. FIREBASE (LOGIN/USE/DEPLOY OPCIONAL)
# ... Código original mantido, mas com deploy automático desativado por padrão ...
if command_exists firebase; then
    log_info "Autenticando no Firebase (use --no-localhost se necessário)..."
    firebase login --no-localhost || log_warning "Login Firebase pulado/sem sucesso; continue se já estiver autenticado."
    FIREBASE_PROJECT="sincroapp-529cc"
    log_info "Selecionando projeto: $FIREBASE_PROJECT"
    firebase use "$FIREBASE_PROJECT" || log_warning "Falha ao selecionar projeto; verifique permissões."

    if [ "$AUTO_DEPLOY_FUNCTIONS" -eq 1 ]; then
        log_info "Deploy automático das Firebase Functions ativado (AUTO_DEPLOY_FUNCTIONS=1)"
        cd "$INSTALL_DIR/functions"
        npm install || log_warning "npm install em functions falhou"
        cd "$INSTALL_DIR"
        firebase deploy --only functions || log_warning "Deploy das Functions falhou. Verifique autenticação e permissões."
    else
        log_warning "Deploy automático desativado. Para deploy manual:"
        log_warning "  cd $INSTALL_DIR && firebase deploy --only functions"
    fi
else
    log_warning "Firebase CLI não encontrado. Pule esta etapa ou instale com: npm i -g firebase-tools"
fi

# 18. VERIFICAR SERVIÇOS
log_info "Verificando status dos serviços..."

# Nginx
if systemctl is-active --quiet nginx; then
    log_success "Nginx: Ativo ✓"
else
    log_error "Nginx: Inativo ✗"
fi

# PM2 Services
if pm2 list | grep -q sincroapp-notifications; then
    log_success "Serviço de Notificações: Ativo ✓"
else
    log_warning "Serviço de Notificações: Não encontrado"
fi

if pm2 list | grep -q sincroapp-backend; then
    log_success "Backend API: Ativo ✓"
elif pm2 list | grep -q sincro-backend; then
     log_warning "Backend API: Ativo (Nome Antigo: sincro-backend) - Será atualizado no próximo deploy"
else
    log_warning "Backend API: Não encontrado"
fi

# 19. TESTE DE SAÚDE
log_info "Executando teste de saúde..."
HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}\n" "https://$DOMAIN")

if [ "$HTTP_STATUS" -eq 200 ] || [ "$HTTP_STATUS" -eq 301 ] || [ "$HTTP_STATUS" -eq 302 ]; then
    log_success "Aplicação respondendo corretamente (HTTP $HTTP_STATUS)"
else
    log_warning "Aplicação retornou HTTP $HTTP_STATUS - verifique os logs"
fi

# 20. LIMPAR BACKUPS ANTIGOS (MANTER APENAS 5 MAIS RECENTES)
log_info "Limpando backups antigos..."
cd "$BACKUP_DIR"
ls -t | tail -n +6 | xargs -r rm -rf
BACKUP_COUNT=$(ls -1 | wc -l)
log_success "Mantendo $BACKUP_COUNT backups mais recentes"

# 21. RESUMO FINAL
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
echo -e "  ${BLUE}└─${NC} Domínio: https://$DOMAIN"
echo ""
log_info "COMANDOS ÚTEIS:"
echo -e "  ${BLUE}├─${NC} Verificar logs Nginx: ${BLUE}tail -f /var/log/nginx/error.log${NC}"
echo -e "  ${BLUE}├─${NC} Verificar logs PM2 (Notif): ${BLUE}pm2 logs sincroapp-notifications${NC}"
echo -e "  ${BLUE}├─${NC} Verificar logs PM2 (API): ${BLUE}pm2 logs sincroapp-backend${NC}"
echo -e "  ${BLUE}├─${NC} Reverter para backup: ${BLUE}cp -r $BACKUP_PATH $INSTALL_DIR${NC}"
echo -e "  ${BLUE}└─${NC} Monitorar serviços: ${BLUE}pm2 monit${NC}"
echo ""

# 22. INFORMAÇÕES DE ROLLBACK
log_warning "EM CASO DE PROBLEMAS:"
echo -e "  ${YELLOW}1.${NC} Para reverter para o backup:"
echo -e "     ${BLUE}sudo rm -rf $INSTALL_DIR${NC}"
echo -e "     ${BLUE}sudo cp -r $BACKUP_PATH $INSTALL_DIR${NC}"
echo -e "     ${BLUE}sudo systemctl reload nginx${NC}"
echo -e "     ${BLUE}sudo pm2 restart sincroapp-notifications${NC}"
echo -e "     ${BLUE}sudo pm2 restart sincroapp-backend${NC}"
echo ""

log_success "Atualização concluída! Acesse https://$DOMAIN para verificar"
