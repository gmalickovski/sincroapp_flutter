#!/bin/bash

###############################################################################
# SincroApp - EXECUTION SCRIPT (start_sincroapp.sh)
# Description: Starts/Restarts all services. Distributes .env first.
###############################################################################

set -e

# --- CONFIG ---
INSTALL_DIR="${INSTALL_DIR:-/var/www/webapp/sincroapp_flutter}"
SUPABASE_DOCKER_DIR="${SUPABASE_DOCKER_DIR:-/root/supabase}" 

# Colors
log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $1"; }
log_warning() { echo -e "\033[1;33m[WARNING]\033[0m $1"; }

log_info "STARTING SERVICES (UNIFIED ENV)..."

cd "$INSTALL_DIR"

# 0. DISTRIBUTE ENV
# Ensure the sub-services have the latest .env from root
if [ -f ".env" ]; then
    log_info "Syncing .env to services..."
    cp ".env" "server/.env"
    cp ".env" "notification-service/.env"
else
    log_error "ROOT .env FILE MISSING in $INSTALL_DIR!"
    log_error "Please create .env with your credentials."
    exit 1
fi

# 1. RESTART SUPABASE FUNCTIONS (Docker)
log_info "Restarting Supabase Edge Functions..."
if [ -d "$SUPABASE_DOCKER_DIR" ]; then
    cd "$SUPABASE_DOCKER_DIR"
    docker compose restart functions || log_warning "Failed to restart Supabase functions container (is docker running?)"
    cd "$INSTALL_DIR"
    log_success "Supabase Functions Container Restarted."
else
    log_warning "Supabase Docker dir ($SUPABASE_DOCKER_DIR) not found."
    log_warning "Skipping container restart. Ensure path is correct in script if running locally."
fi

# 2. START NODE.JS SERVER
log_info "Starting Main Server..."
if [ -d "server" ]; then
    cd server
    pm2 delete sincroapp-server 2>/dev/null || true
    pm2 start index.js --name sincroapp-server --time --env ../.env
    pm2 save
    log_success "PM2: sincroapp-server started."
    cd ..
fi

# 3. START NOTIFICATION SERVICE
log_info "Starting Notification Service..."
if [ -d "notification-service" ]; then
    cd notification-service
    pm2 delete sincroapp-notifications 2>/dev/null || true
    # Note: pm2 --env option often applies to ecosystem.config.js, but explicit file usage works too if code uses dotenv
    pm2 start index.js --name sincroapp-notifications --time
    pm2 save
    log_success "PM2: sincroapp-notifications started."
    cd ..
fi

# 4. NGINX RELOAD
log_info "Reloading Nginx..."
nginx -t
if [ $? -eq 0 ]; then
    systemctl reload nginx
    log_success "Nginx Reloaded."
else
    log_warning "Nginx config check failed. Skipping reload."
fi

# 5. STATUS
echo ""
log_info "CURRENT PM2 STATUS:"
pm2 list
