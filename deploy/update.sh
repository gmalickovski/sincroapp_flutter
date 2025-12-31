#!/bin/bash

###############################################################################
# SincroApp - UPDATE SCRIPT (update.sh)
# Description: Stops services, Updates code, Rebuilds, Restarts services.
# Includes automatic backup before update.
###############################################################################

set -e

# --- CONFIG ---
INSTALL_DIR="${INSTALL_DIR:-/var/www/webapp/sincroapp_flutter}"
BACKUP_STORAGE="${BACKUP_STORAGE:-/var/www/webapp/backup_sincroapp}"
SUPABASE_DOCKER_DIR="${SUPABASE_DOCKER_DIR:-/root/supabase}" 
BRANCH="${BRANCH:-main}"

# Colors
log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $1"; }
log_warning() { echo -e "\033[1;33m[WARNING]\033[0m $1"; }

log_info "STARTING UPDATE (Branch: $BRANCH)..."

# 1. STOP SERVICES (Prevent conflict during update)
log_info "Stopping Services..."
pm2 stop sincro-web-server sincroapp-server sincroapp-notifications 2>/dev/null || true
log_success "Services stopped."

# 2. AUTO BACKUP
log_info "Creating Pre-Update Backup..."
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="$BACKUP_STORAGE/backup_$TIMESTAMP"
mkdir -p "$BACKUP_PATH"

if [ -d "$INSTALL_DIR" ]; then
    cp -r "$INSTALL_DIR"/* "$BACKUP_PATH/" || true
    # Backup ROOT .env (hidden file)
    [ -f "$INSTALL_DIR/.env" ] && cp "$INSTALL_DIR/.env" "$BACKUP_PATH/root.env"
    log_success "Backup saved to $BACKUP_PATH"
else
    log_error "Install directory not found!"
    exit 1
fi

# 3. GIT UPDATE
cd "$INSTALL_DIR"
git stash
git fetch origin
git checkout "$BRANCH"
git pull origin "$BRANCH"
log_success "Code updated."

# 4. RESTORE & DISTRIBUTE ENV
# Ensure we have the .env keys before building/running
if [ -f "$BACKUP_PATH/root.env" ] && [ ! -f ".env" ]; then
    cp "$BACKUP_PATH/root.env" ".env"
    log_info "Restored root .env from backup."
fi
# Sync to sub-folders (Unified Env Strategy)
[ -f ".env" ] && cp ".env" "server/.env"
[ -f ".env" ] && cp ".env" "notification-service/.env"

# 5. BUILD FLUTTER
log_info "Rebuilding Flutter Web..."
# Compat fixes if needed
sed -i 's/intl: \^0\.20\.2/intl: ^0.19.0/' pubspec.yaml
sed -i 's/collection: \^1\.19\.1/collection: ^1.18.0/' pubspec.yaml

flutter pub get
flutter clean
flutter build web --release --base-href /app/

# Static files fix
cp -f web/firebase-config.js build/web/firebase-config.js 2>/dev/null || true
cp -f web/favicon.png build/web/favicon.png 2>/dev/null || true
if [ -d "web/icons" ]; then cp -rf web/icons build/web/; fi

chown -R www-data:www-data build/web
chmod -R 755 build/web
log_success "Flutter Rebuilt."

# 6. UPDATE DEPENDENCIES
log_info "Updating Backend Deps..."
[ -d "server" ] && (cd server && npm install)
[ -d "notification-service" ] && (cd notification-service && npm install)

# 7. UPDATE SUPABASE FUNCTIONS
log_info "Updating Supabase Functions..."
if [ -d "$SUPABASE_DOCKER_DIR" ]; then
    cp -r supabase/functions/* "$SUPABASE_DOCKER_DIR/volumes/functions/"
    (cd "$SUPABASE_DOCKER_DIR" && docker compose restart functions)
    log_success "Supabase Functions Restarted."
fi

# 8. START SERVICES
log_info "Restarting PM2 Services..."

# Restart all services (preserves existing config)
pm2 restart sincro-web-server --update-env 2>/dev/null || log_warning "sincro-web-server not found to restart."
pm2 restart sincroapp-server --update-env 2>/dev/null || log_warning "sincroapp-server not found to restart."
pm2 restart sincroapp-notifications --update-env 2>/dev/null || log_warning "sincroapp-notifications not found to restart."

pm2 save

# Nginx
log_info "Reloading Nginx..."
systemctl reload nginx

log_success "UPDATE COMPLETED SUCCESSFULLY."
