#!/bin/bash

###############################################################################
# Script de Instalação do Zero (Com Restore de Backup) - SincroApp
# Autor: Equipe Sincro (Atualizado)
# Data: 2025-01-09
# Descrição: Instala o sistema do zero ou restaura de um backup existente.
###############################################################################

set -e

# --- CONFIG ---
INSTALL_DIR="${INSTALL_DIR:-/var/www/webapp/sincroapp_flutter}"
GITHUB_REPO="${GITHUB_REPO:-https://github.com/gmalickovski/sincroapp_flutter.git}"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/sincroapp_flutter}"
DOMAIN="${DOMAIN:-sincroapp.com.br}"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      SINCROAPP - MAGIC INSTALLER (FRESH OR RESTORE)        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"

# 1. VERIFICAR ROOT
if [ "$EUID" -ne 0 ]; then
    log_error "Execute como root (sudo)."
    exit 1
fi

# 2. CHECKAR BACKUPS EXISTENTES
LATEST_BACKUP=""
if [ -d "$BACKUP_DIR" ]; then
    LATEST_BACKUP=$(ls -td "$BACKUP_DIR"/backup_* 2>/dev/null | head -1)
fi

RESTORE_MODE="no"

if [ -n "$LATEST_BACKUP" ]; then
    log_info "Backup detectado: $(basename "$LATEST_BACKUP")"
    echo -e "${YELLOW}Deseja restaurar este backup ao invés de clonar do zero? [S/n]${NC}"
    read -r response
    if [[ "$response" =~ ^([nN][oO]|[nN])$ ]]; then
        RESTORE_MODE="no"
    else
        RESTORE_MODE="yes"
    fi
fi

# 3. PREPARAR DIRETÓRIO
if [ -d "$INSTALL_DIR" ]; then
    log_warning "Diretório de instalação já existe: $INSTALL_DIR"
    echo "Deseja remover e reinstalar? (Isso apagará a versão atual não salva) [y/N]"
    read -r clean_confirm
    if [[ "$clean_confirm" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        rm -rf "$INSTALL_DIR"
        log_success "Diretório limpo."
    else
        log_error "Instalação cancelada para evitar perda de dados."
        exit 1
    fi
fi

mkdir -p "$(dirname "$INSTALL_DIR")"

# 4. EXECUÇÃO DA INSTALAÇÃO (RESTORE OU CLONE)

if [ "$RESTORE_MODE" == "yes" ]; then
    log_info "Restaurando backup de $LATEST_BACKUP..."
    cp -r "$LATEST_BACKUP" "$INSTALL_DIR"
    log_success "Backup restaurado em $INSTALL_DIR"
    
    # Se houver config do Nginx salva, restaurar
    if [ -f "$LATEST_BACKUP/nginx_config.bak" ]; then
        log_info "Restaurando config do Nginx..."
        cp "$LATEST_BACKUP/nginx_config.bak" "/etc/nginx/sites-available/$DOMAIN"
        ln -sf "/etc/nginx/sites-available/$DOMAIN" "/etc/nginx/sites-enabled/"
        log_success "Nginx configurado do backup."
    fi
else
    log_info "Realizando instalação limpa (Clone do Git)..."
    git clone "$GITHUB_REPO" "$INSTALL_DIR"
    log_success "Repositório clonado."
fi

# 5. AJUSTAR PERMISSÕES INICIAIS
cd "$INSTALL_DIR"
chmod +x deploy/*.sh
chmod +x server/*.sh 2>/dev/null || true

# 6. CONFIGURAR AMBIENTE (SE NECESSÁRIO)
if [ ! -f ".env" ]; then
    log_warning "Arquivo .env não encontrado!"
    if [ -f "deploy/.env.example" ]; then
        cp deploy/.env.example .env
        log_warning "Criado .env a partir do exemplo. EDITE-O IMEDIATAMENTE!"
    else
        log_warning "Crie o arquivo .env com suas chaves de API."
    fi
fi

# 7. EXECUTAR UPDATE COMPLETO (GARANTE QUE TUDO ESTÁ INSTALADO/ATUALIZADO)
log_info "Executando script de atualização para instalar dependências e buildar..."

# Usar o script de update que acabamos de baixar/restaurar
# Se não existir no restore (backup antigo), baixa do repo ou usa local se clone novo
if [ -f "deploy/update.sh" ]; then
    # Garantir que é executável
    chmod +x deploy/update.sh
    ./deploy/update.sh
else
    # Fallback se o update.sh não existir (não deveria acontecer num clone recente)
    log_error "Script deploy/update.sh não encontrado. Instalação manual necessária."
    exit 1
fi

log_success "INSTALAÇÃO DO ZERO CONCLUÍDA!"
log_info "Acesse https://$DOMAIN"
