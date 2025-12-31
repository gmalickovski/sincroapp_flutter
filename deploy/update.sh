#!/bin/bash

###############################################################################
# SincroApp - UPDATE SCRIPT (update.sh)
# Description: Updates system maintaining Unified .env strategy.
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

log_info "STARTING UPDATE (Unified Env)..."

# 1. AUTO BACKUP
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

# 2. GIT UPDATE
cd "$INSTALL_DIR"
git stash
git fetch origin
git checkout "$BRANCH"
git pull origin "$BRANCH"
log_success "Code updated."

# 3. RESTORE & DISTRIBUTE ENV
if [ -f "$BACKUP_PATH/root.env" ]; then
    cp "$BACKUP_PATH/root.env" ".env"
    log_info "Restored root .env"
fi
[ -f ".env" ] && cp ".env" "server/.env"
[ -f ".env" ] && cp ".env" "notification-service/.env"

# 4. BUILD FLUTTER
log_info "Rebuilding Flutter Web..."
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

# 5. UPDATE DEPS
log_info "Updating Backend Deps..."
[ -d "server" ] && (cd server && npm install)
[ -d "notification-service" ] && (cd notification-service && npm install)

# 6. UPDATE SUPABASE FUNCTIONS
if [ -d "$SUPABASE_DOCKER_DIR" ]; then
    cp -r supabase/functions/* "$SUPABASE_DOCKER_DIR/volumes/functions/"
    (cd "$SUPABASE_DOCKER_DIR" && docker compose restart functions)
fi

# 7. RESTART SERVICES (call start script logic inline)
if [ -d "server" ]; then
    pm2 delete sincroapp-server 2>/dev/null || true
    (cd server && pm2 start index.js --name sincroapp-server --time)
fi
if [ -d "notification-service" ]; then
    pm2 delete sincroapp-notifications 2>/dev/null || true
    (cd notification-service && pm2 start index.js --name sincroapp-notifications --time)
fi
pm2 save

systemctl reload nginx
log_success "UPDATE COMPLETED."
