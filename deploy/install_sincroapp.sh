#!/bin/bash

###############################################################################
# SincroApp - INSTALLATION SCRIPT (install_sincroapp.sh)
# Description: Downloads code, installs dependencies, builds app, prepares deployment.
# DOES NOT start the servers (use start_sincroapp.sh for that).
###############################################################################

set -e

# --- CONFIG ---
INSTALL_DIR="${INSTALL_DIR:-/var/www/webapp/sincroapp_flutter}"
GITHUB_REPO="${GITHUB_REPO:-https://github.com/gmalickovski/sincroapp_flutter.git}"
BRANCH="${BRANCH:-main}"
SUPABASE_DOCKER_DIR="${SUPABASE_DOCKER_DIR:-/root/supabase}" 

# Colors
log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $1"; }

log_info "STARTING INSTALLATION SCRIPT..."
log_info "Target Directory: $INSTALL_DIR"
log_info "Branch: $BRANCH"

# 1. GIT CLONE / PULL
if [ -d "$INSTALL_DIR" ]; then
    log_info "Directory exists. Pulling latest changes..."
    cd "$INSTALL_DIR"
    git fetch origin
    git checkout "$BRANCH"
    git pull origin "$BRANCH"
else
    log_info "Directory does not exist. Cloning repo..."
    mkdir -p "$(dirname "$INSTALL_DIR")"
    git clone -b "$BRANCH" "$GITHUB_REPO" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi
log_success "Codebase updated."

# 2. FLUTTER WEB BUILD
log_info "Preparing Flutter Web..."

# Pubspec Fixes (VPS Compatibility)
sed -i 's/intl: \^0\.20\.2/intl: ^0.19.0/' pubspec.yaml
sed -i 's/collection: \^1\.19\.1/collection: ^1.18.0/' pubspec.yaml
# Add other seds from previous script if strictly necessary

flutter pub get
flutter clean
flutter build web --release --base-href /app/

if [ ! -d "build/web" ]; then
    log_error "Flutter Build Failed!"
    exit 1
fi
log_success "Flutter Web Built."

# 3. PUBLISH STATIC FILES
log_info "Copying static files to build/web..."
cp -f web/landing.html build/web/landing.html
cp -f web/landing.js build/web/landing.js
cp -f web/firebase-config.js build/web/firebase-config.js
cp -f web/favicon.png build/web/favicon.png 2>/dev/null || true
if [ -d "web/icons" ]; then cp -rf web/icons build/web/; fi

# Permissions
chown -R www-data:www-data build/web
chmod -R 755 build/web

# 4. INSTALL BACKEND DEPENDENCIES (SERVER)
log_info "Installing Node Server dependencies..."
if [ -d "server" ]; then
    cd server
    npm install
    cd ..
else
    log_error "server/ directory missing!"
fi

# 5. INSTALL NOTIFICATION SERVICE DEPENDENCIES
log_info "Installing Notification Service dependencies..."
if [ -d "notification-service" ]; then
    cd notification-service
    npm install
    cd ..
else
    log_error "notification-service/ directory missing!"
fi

# 6. INSTALL FIREBASE FUNCTIONS DEPENDENCIES (Legacy support)
log_info "Installing Firebase Functions dependencies..."
if [ -d "functions" ]; then
    cd functions
    npm install
    cd ..
fi

# 7. DEPLOY SUPABASE FUNCTIONS (Copy to Docker Volume)
log_info "Deploying Supabase Edge Functions to Docker..."
if [ -d "$SUPABASE_DOCKER_DIR" ]; then
    DEST_FUNCTIONS="$SUPABASE_DOCKER_DIR/volumes/functions"
    mkdir -p "$DEST_FUNCTIONS"
    
    # Copy generic functions folder content
    cp -r supabase/functions/* "$DEST_FUNCTIONS/"
    log_success "Supabase Functions files copied to $DEST_FUNCTIONS"
else
    log_warning "Supabase Docker Directory ($SUPABASE_DOCKER_DIR) NOT FOUND."
    log_warning "Skipping function deployment. Copy 'supabase/functions' manually."
fi

log_success "INSTALLATION SCRIPT COMPLETED SUCCESSFULLY."
log_info "Now run: ./deploy/start_sincroapp.sh"
