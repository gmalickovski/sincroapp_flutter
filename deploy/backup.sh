#!/bin/bash

###############################################################################
# SincroApp - BACKUP SCRIPT (backup.sh)
###############################################################################

set -e

# --- CONFIG ---
INSTALL_DIR="${INSTALL_DIR:-/var/www/webapp/sincroapp_flutter}"
BACKUP_STORAGE="${BACKUP_STORAGE:-/var/www/webapp/backup_sincroapp}"

# Colors
log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $1"; }

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="$BACKUP_STORAGE/backup_$TIMESTAMP"

log_info "STARTING MANUAL BACKUP..."
log_info "Source: $INSTALL_DIR"
log_info "Destination: $BACKUP_PATH"

if [ ! -d "$INSTALL_DIR" ]; then
    log_error "Installation directory check failed. Nothing to backup."
    exit 1
fi

mkdir -p "$BACKUP_PATH"

# 1. COPY FILES
log_info "Copying files..."
cp -r "$INSTALL_DIR"/* "$BACKUP_PATH/"

# 2. ENSURE .env IS COPIED
if [ -f "$INSTALL_DIR/.env" ]; then
    cp "$INSTALL_DIR/.env" "$BACKUP_PATH/root.env"
    log_success "Backed up ROOT .env"
else
    log_error "ROOT .env NOT FOUND! Checking sub-directories as fallback..."
    [ -f "$INSTALL_DIR/server/.env" ] && cp "$INSTALL_DIR/server/.env" "$BACKUP_PATH/server.env"
    [ -f "$INSTALL_DIR/notification-service/.env" ] && cp "$INSTALL_DIR/notification-service/.env" "$BACKUP_PATH/notification.env"
fi

# 3. ROTATE BACKUPS (Keep last 5)
cd "$BACKUP_STORAGE"
ls -dt backup_* | tail -n +6 | xargs -r rm -rf

log_success "BACKUP COMPLETED: $BACKUP_PATH"
