#!/bin/bash

###############################################################################
# SincroApp - INSTALLATION SCRIPT (install_sincroapp.sh)
# Description: Clean Install with Backup Persistence.
# 1. Backs up ROOT .env file to BACKUP_STORAGE
# 2. Deletes existing app directory
# 3. Fresh clones from GitHub
# 4. Restores .env file to root and copies to services
# 5. Installs dependencies & Builds
###############################################################################

set -e

# --- CONFIG ---
INSTALL_DIR="${INSTALL_DIR:-/var/www/webapp/sincroapp_flutter}"
BACKUP_STORAGE="${BACKUP_STORAGE:-/var/www/webapp/backup_sincroapp}"
GITHUB_REPO="${GITHUB_REPO:-https://github.com/gmalickovski/sincroapp_flutter.git}"
BRANCH="${BRANCH:-main}"
SUPABASE_DOCKER_DIR="${SUPABASE_DOCKER_DIR:-/root/supabase}" 

# Colors
log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $1"; }
log_warning() { echo -e "\033[1;33m[WARNING]\033[0m $1"; }

log_info "STARTING CLEAN INSTALLATION (UNIFIED ENV)..."
log_info "Target Directory: $INSTALL_DIR"
log_info "Backup Storage: $BACKUP_STORAGE"

# 1. PRE-INSTALL BACKUP (PERSIST CREDENTIALS)
log_info "Persisting ROOT .env to backup storage..."
mkdir -p "$BACKUP_STORAGE"

if [ -f "$INSTALL_DIR/.env" ]; then
    cp "$INSTALL_DIR/.env" "$BACKUP_STORAGE/root.env.bak"
    log_success "Saved root .env"
elif [ -f "$INSTALL_DIR/server/.env" ]; then
    # Fallback for migration: if root .env missing, try saving server .env
    cp "$INSTALL_DIR/server/.env" "$BACKUP_STORAGE/root.env.bak"
    log_warning "Root .env missing. Saved server/.env as backup instead."
fi

# 2. WIPE & CLONE
if [ -d "$INSTALL_DIR" ]; then
    log_warning "Deleting old installation directory..."
    rm -rf "$INSTALL_DIR"
fi

log_info "Cloning fresh repository (Branch: $BRANCH)..."
mkdir -p "$(dirname "$INSTALL_DIR")"
git clone -b "$BRANCH" "$GITHUB_REPO" "$INSTALL_DIR"

if [ ! -d "$INSTALL_DIR" ]; then
    log_error "Git Clone Failed!"
    exit 1
fi
cd "$INSTALL_DIR"
log_success "Repository cloned."

# 3. RESTORE CREDENTIALS & DISTRIBUTE
log_info "Restoring credentials..."

if [ -f "$BACKUP_STORAGE/root.env.bak" ]; then
    cp "$BACKUP_STORAGE/root.env.bak" ".env"
    log_success "Restored .env to root."
else
    log_warning "No key backup found! You must create .env manually in $INSTALL_DIR"
fi

# Distribute .env to services
log_info "Distributing .env to sub-services..."
[ -f ".env" ] && cp ".env" "server/.env" && log_success "Copied .env to server/"
[ -f ".env" ] && cp ".env" "notification-service/.env" && log_success "Copied .env to notification-service/"

# 4. FLUTTER WEB BUILD
log_info "Building Flutter Web..."
sed -i 's/intl: \^0\.20\.2/intl: ^0.19.0/' pubspec.yaml
sed -i 's/collection: \^1\.19\.1/collection: ^1.18.0/' pubspec.yaml

flutter pub get
flutter clean
flutter build web --release --base-href /app/

if [ ! -d "build/web" ]; then
    log_error "Flutter Build Failed!"
    exit 1
fi
log_success "Flutter Web Built."

# 5. PUBLISH STATIC FILES
log_info "Copying static files..."
cp -f web/firebase-config.js build/web/firebase-config.js 2>/dev/null || true
cp -f web/favicon.png build/web/favicon.png 2>/dev/null || true
if [ -d "web/icons" ]; then cp -rf web/icons build/web/; fi

chown -R www-data:www-data build/web
chmod -R 755 build/web

# 6. INSTALL SERVER DEPENDENCIES
log_info "Installing Dependencies..."
if [ -d "server" ]; then cd server && npm install && cd ..; fi
if [ -d "notification-service" ]; then cd notification-service && npm install && cd ..; fi
# functions deprecated/migrating, but installing just in case
if [ -d "functions" ]; then cd functions && npm install && cd ..; fi

# 7. DEPLOY SUPABASE FUNCTIONS
log_info "Deploying Supabase Functions..."
if [ -d "$SUPABASE_DOCKER_DIR" ]; then
    DEST_FUNCTIONS="$SUPABASE_DOCKER_DIR/volumes/functions"
    mkdir -p "$DEST_FUNCTIONS"
    cp -r supabase/functions/* "$DEST_FUNCTIONS/"
    log_success "Functions copied to Docker volume."
else
    log_warning "Supabase Docker Path ($SUPABASE_DOCKER_DIR) not found on host."
    log_warning "SKIPPING function copy. Update SUPABASE_DOCKER_DIR in script if needed."
fi

log_success "INSTALLATION COMPLETE. Run ./deploy/start_sincroapp.sh to start services."
