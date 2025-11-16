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

# Configurações
INSTALL_DIR="/var/www/webapp/sincroapp_flutter"
GITHUB_REPO="https://github.com/gmalickovski/sincroapp_flutter.git"
NGINX_CONFIG="/etc/nginx/sites-available/sincroapp.com.br"
NGINX_ENABLED="/etc/nginx/sites-enabled/sincroapp.com.br"
DOMAIN="sincroapp.com.br"
NODE_VERSION="20"

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

# 2. ATUALIZAR SISTEMA
log_info "Atualizando sistema operacional..."
apt-get update -qq
apt-get upgrade -y -qq
log_success "Sistema atualizado"

# 3. INSTALAR DEPENDÊNCIAS BASE
log_info "Instalando dependências base..."
apt-get install -y -qq \
    curl \
    wget \
    git \
    unzip \
    build-essential \
    nginx \
    certbot \
    python3-certbot-nginx \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release
log_success "Dependências base instaladas"

# 4. INSTALAR NODE.JS E NPM
if ! command_exists node; then
    log_info "Instalando Node.js ${NODE_VERSION}..."
    curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -
    apt-get install -y nodejs
    log_success "Node.js $(node --version) instalado"
else
    log_success "Node.js $(node --version) já instalado"
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
    wget -q https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.5-stable.tar.xz
    tar xf flutter_linux_3.24.5-stable.tar.xz
    rm flutter_linux_3.24.5-stable.tar.xz
    
    # Adicionar ao PATH para todas as sessões (profile.d)
    echo 'export PATH="$PATH:/opt/flutter/bin"' > /etc/profile.d/flutter.sh
    chmod 644 /etc/profile.d/flutter.sh
    export PATH="$PATH:/opt/flutter/bin"

    # Corrigir aviso de "dubious ownership" ao rodar como root
    git config --global --add safe.directory /opt/flutter || true

    # Configurar Flutter e atualizar para a última estável
    flutter config --no-analytics || true
    flutter channel stable || true
    flutter upgrade || true
    flutter precache --web || true
    flutter --version || true

    log_success "Flutter SDK instalado e atualizado (canal estável)"
else
    log_success "Flutter SDK já instalado"
    git config --global --add safe.directory /opt/flutter || true
    flutter channel stable || true
    flutter upgrade || true
    flutter --version || true
fi

# 7. INSTALAR PM2 PARA GERENCIAR SERVIÇO DE NOTIFICAÇÕES
if ! command_exists pm2; then
    log_info "Instalando PM2..."
    npm install -g pm2
    pm2 startup systemd -u root --hp /root
    log_success "PM2 instalado"
else
    log_success "PM2 já instalado"
fi

# 8. CLONAR REPOSITÓRIO DO GITHUB
log_info "Clonando repositório do GitHub..."
if [ -d "$INSTALL_DIR" ]; then
    log_warning "Diretório $INSTALL_DIR já existe. Removendo..."
    rm -rf "$INSTALL_DIR"
fi

mkdir -p "$(dirname "$INSTALL_DIR")"
git clone "$GITHUB_REPO" "$INSTALL_DIR"
cd "$INSTALL_DIR"
log_success "Repositório clonado"

# 9. INSTALAR DEPENDÊNCIAS FLUTTER
log_info "Instalando dependências Flutter..."
flutter pub get
log_success "Dependências Flutter instaladas"

# 10. INSTALAR DEPENDÊNCIAS FIREBASE FUNCTIONS
log_info "Instalando dependências Firebase Functions..."
cd "$INSTALL_DIR/functions"
npm install
cd "$INSTALL_DIR"
log_success "Dependências Firebase Functions instaladas"

# 11. INSTALAR DEPENDÊNCIAS SERVIÇO DE NOTIFICAÇÕES
if [ -d "$INSTALL_DIR/notification-service" ]; then
    log_info "Instalando dependências do Serviço de Notificações..."
    cd "$INSTALL_DIR/notification-service"
    npm install
    cd "$INSTALL_DIR"
    log_success "Dependências do Serviço de Notificações instaladas"
fi

# 12. BUILD FLUTTER WEB
log_info "Gerando build Flutter Web (isso pode demorar alguns minutos)..."
flutter build web --release --web-renderer html
log_success "Build Flutter Web concluído"

# 13. CONFIGURAR FIREBASE (INTERATIVO)
log_warning "ATENÇÃO: Você precisa fazer login no Firebase e configurar o projeto"
log_info "1. Execute: firebase login (em sua máquina local)"
log_info "2. Copie o arquivo de credenciais para o servidor"
log_info "Pressione ENTER para continuar após configurar as credenciais..."
read -r

# 14. CONFIGURAR NGINX
log_info "Configurando Nginx..."

# Backup da configuração antiga se existir
if [ -f "$NGINX_CONFIG" ]; then
    cp "$NGINX_CONFIG" "${NGINX_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
    log_info "Backup da configuração antiga criado"
fi

# Criar nova configuração
cat > "$NGINX_CONFIG" << 'EOF'
# Bloco HTTP: Redireciona todo o tráfego para HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name sincroapp.com.br www.sincroapp.com.br;

    root /var/www/webapp/sincroapp_flutter/build/web;

    location /.well-known/acme-challenge/ {
        allow all;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

# Bloco HTTPS: Serve a aplicação Flutter Web
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name sincroapp.com.br www.sincroapp.com.br;

    root /var/www/webapp/sincroapp_flutter/build/web;
    index index.html;

    # Configuração para SPA (Single Page Application)
    location / {
        try_files $uri $uri/ /index.html;
    }
    
    # Cache para arquivos estáticos
    location ~* \.(?:css|js|jpg|jpeg|gif|png|ico|svg|webp|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Desabilitar cache para index.html
    location = /index.html {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
        add_header Expires "0";
    }

    # SSL (será configurado pelo Certbot)
    ssl_certificate /etc/letsencrypt/live/sincroapp.com.br/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/sincroapp.com.br/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    # Headers de segurança
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Compressão Gzip
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/json application/javascript;
}
EOF

# Habilitar site
ln -sf "$NGINX_CONFIG" "$NGINX_ENABLED"

# Testar configuração
nginx -t
if [ $? -eq 0 ]; then
    log_success "Configuração Nginx criada e validada"
else
    log_error "Erro na configuração do Nginx"
    exit 1
fi

# 15. CONFIGURAR SSL (SE NÃO EXISTIR)
if [ ! -d "/etc/letsencrypt/live/$DOMAIN" ]; then
    log_info "Configurando SSL com Certbot..."
    log_warning "ATENÇÃO: Certifique-se de que o domínio $DOMAIN está apontando para este servidor"
    log_info "Pressione ENTER para continuar com a configuração SSL..."
    read -r
    
    certbot --nginx -d "$DOMAIN" -d "www.$DOMAIN" --non-interactive --agree-tos --email admin@$DOMAIN || {
        log_warning "Certbot falhou. Você pode executar manualmente depois: certbot --nginx -d $DOMAIN -d www.$DOMAIN"
    }
else
    log_success "Certificado SSL já existe"
fi

# 16. RECARREGAR NGINX
log_info "Recarregando Nginx..."
systemctl reload nginx
log_success "Nginx recarregado"

# Recarregar variáveis de ambiente globais (para sessões futuras)
if [ -f /etc/profile.d/flutter.sh ]; then
    . /etc/profile.d/flutter.sh || true
fi

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

# 18. CONFIGURAR FIREBASE FUNCTIONS (PREPARAÇÃO)
log_info "Preparando Firebase Functions..."
cd "$INSTALL_DIR"
log_warning "Para fazer deploy das Functions, execute manualmente:"
log_warning "  cd $INSTALL_DIR"
log_warning "  firebase login (se necessário)"
log_warning "  firebase deploy --only functions"

# 19. CONFIGURAR PERMISSÕES
log_info "Configurando permissões..."
chown -R www-data:www-data "$INSTALL_DIR/build/web"
chmod -R 755 "$INSTALL_DIR/build/web"
log_success "Permissões configuradas"

# 20. CONFIGURAR FIREWALL (UFW)
if command_exists ufw; then
    log_info "Detectado UFW instalado. Não vamos habilitar nem alterar regras automaticamente para evitar interferir com Docker e outros serviços."
    UFW_STATUS=$(ufw status | head -n 1 | awk '{print tolower($2)}')
    if [ "$UFW_STATUS" = "active" ]; then
        log_info "UFW está ativo. Adicionando apenas regras necessárias, sem alterar políticas."
        ufw allow 'Nginx Full' || true
        ufw allow 22 || true
        log_success "Regras do UFW ajustadas (sem alterar estado)."
    else
        log_warning "UFW está inativo. Mantendo inativo para não impactar containers Docker e outros apps."
    fi
fi

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

# 22. CRIAR SCRIPT DE ATUALIZAÇÃO
log_info "Criando script de atualização..."
cat > "$INSTALL_DIR/deploy/update.sh" << 'UPDATEEOF'
#!/bin/bash
# Este script foi gerado automaticamente pelo instalador
source "$(dirname "$0")/install.sh"
UPDATEEOF
chmod +x "$INSTALL_DIR/deploy/update.sh"
log_success "Script de atualização criado"

# 23. RESUMO FINAL
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           INSTALAÇÃO CONCLUÍDA COM SUCESSO!                ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
log_info "RESUMO DA INSTALAÇÃO:"
echo -e "  ${BLUE}├─${NC} Diretório de instalação: $INSTALL_DIR"
echo -e "  ${BLUE}├─${NC} Build Flutter Web: $INSTALL_DIR/build/web"
echo -e "  ${BLUE}├─${NC} Configuração Nginx: $NGINX_CONFIG"
echo -e "  ${BLUE}├─${NC} Domínio: https://$DOMAIN"
echo -e "  ${BLUE}└─${NC} Serviço de Notificações: PM2 (sincroapp-notifications)"
echo ""
log_info "PRÓXIMOS PASSOS:"
echo -e "  ${YELLOW}1.${NC} Configure as credenciais do Firebase:"
echo -e "     ${BLUE}firebase login${NC}"
echo -e "  ${YELLOW}2.${NC} Faça deploy das Functions:"
echo -e "     ${BLUE}cd $INSTALL_DIR && firebase deploy --only functions${NC}"
echo -e "  ${YELLOW}3.${NC} Configure as variáveis de ambiente no Firebase Functions"
echo -e "  ${YELLOW}4.${NC} Acesse: ${GREEN}https://$DOMAIN${NC}"
echo ""
log_info "COMANDOS ÚTEIS:"
echo -e "  ${BLUE}├─${NC} Verificar logs Nginx: ${BLUE}tail -f /var/log/nginx/error.log${NC}"
echo -e "  ${BLUE}├─${NC} Verificar logs PM2: ${BLUE}pm2 logs sincroapp-notifications${NC}"
echo -e "  ${BLUE}├─${NC} Reiniciar Nginx: ${BLUE}systemctl reload nginx${NC}"
echo -e "  ${BLUE}├─${NC} Reiniciar Notificações: ${BLUE}pm2 restart sincroapp-notifications${NC}"
echo -e "  ${BLUE}└─${NC} Atualizar sistema: ${BLUE}$INSTALL_DIR/deploy/update.sh${NC}"
echo ""
log_success "Sistema instalado e pronto para uso!"
