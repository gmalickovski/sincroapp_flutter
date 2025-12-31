#!/bin/bash

###############################################################################
# SincroApp - EXECUTION SCRIPT (start_sincroapp.sh)
# Description: Starts/Restarts all services (Node Server, Notifications, Nginx, Supabase Functions).
###############################################################################

set -e

# --- CONFIG ---
INSTALL_DIR="${INSTALL_DIR:-/var/www/webapp/sincroapp_flutter}"
SUPABASE_DOCKER_DIR="${SUPABASE_DOCKER_DIR:-/root/supabase}" 

# Colors
log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $1"; }

log_info "STARTING SERVICES..."

# 1. RESTART SUPABASE FUNCTIONS (Docker)
log_info "Restarting Supabase Edge Functions..."
if [ -d "$SUPABASE_DOCKER_DIR" ]; then
    cd "$SUPABASE_DOCKER_DIR"
    docker compose restart functions || log_error "Failed to restart Supabase functions container."
    cd "$INSTALL_DIR"
    log_success "Supabase Functions Container Restarted."
else
    log_info "Supabase Docker dir not found, skipping container restart."
fi

# 2. START NODE.JS SERVER (API/Static)
log_info "Starting Main Server (server/index.js)..."
if [ -d "$INSTALL_DIR/server" ]; then
    cd "$INSTALL_DIR/server"
    # Ensure env exists
    if [ ! -f .env ]; then
        log_error "Missing .env in server directory!"
    else
        pm2 delete sincroapp-server 2>/dev/null || true
        pm2 start index.js --name sincroapp-server --time
        pm2 save
        log_success "PM2: sincroapp-server started."
    fi
    cd "$INSTALL_DIR"
fi

# 3. START NOTIFICATION SERVICE
log_info "Starting Notification Service (notification-service/index.js)..."
if [ -d "$INSTALL_DIR/notification-service" ]; then
    cd "$INSTALL_DIR/notification-service"
    if [ ! -f .env ]; then
        log_error "Missing .env in notification-service directory! Copy example or create one."
    else
        pm2 delete sincroapp-notifications 2>/dev/null || true
        pm2 start index.js --name sincroapp-notifications --time
        pm2 save
        log_success "PM2: sincroapp-notifications started."
    fi
    cd "$INSTALL_DIR"
fi

# 4. NGINX RELOAD
log_info "Testing and Reloading Nginx..."
nginx -t
if [ $? -eq 0 ]; then
    systemctl reload nginx
    log_success "Nginx Reloaded."
else
    log_error "Nginx Configuration Test Failed! Check /etc/nginx/sites-available/sincroapp.com.br"
    exit 1
fi

# 5. STATUS REPORT
echo ""
log_info "CURRENT PM2 STATUS:"
pm2 list
echo ""
log_info "NGINX STATUS:"
department=$(systemctl is-active nginx)
echo "Nginx is: $department"

log_success "ALL SYSTEM EXECUTED SUCCESSFULLY!"
