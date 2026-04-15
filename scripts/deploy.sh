#!/usr/bin/env bash
# Initial deployment script for generic-backend
# Run as root on the target VPS:
#   curl -fsSL https://raw.githubusercontent.com/YOUR_ORG/YOUR_REPO/main/scripts/deploy.sh | bash
# Or clone the repo and run:
#   sudo bash scripts/deploy.sh
set -euo pipefail

REPO_URL="${REPO_URL:-}"          # set via env or edit below
DEPLOY_DIR="/opt/generic-backend"
SERVICE_NAME="generic-backend"
APP_USER="www-data"
NGINX_CONF="/etc/nginx/sites-available/${SERVICE_NAME}"

# ── helpers ────────────────────────────────────────────────────────────────────
log()  { echo "[deploy] $*"; }
die()  { echo "[deploy] ERROR: $*" >&2; exit 1; }

[[ "$EUID" -eq 0 ]] || die "Run as root (sudo bash scripts/deploy.sh)"

# ── 1. required packages ───────────────────────────────────────────────────────
log "Installing system packages..."
apt-get update -qq
apt-get install -y -qq git curl nginx

# ── 2. install uv ─────────────────────────────────────────────────────────────
if ! command -v uv &>/dev/null; then
    log "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.cargo/bin:$PATH"
    # make uv available system-wide
    ln -sf "$(command -v uv)" /usr/local/bin/uv
fi
log "uv version: $(uv --version)"

# ── 3. clone / update repo ────────────────────────────────────────────────────
if [[ -d "$DEPLOY_DIR/.git" ]]; then
    log "Repo already exists at $DEPLOY_DIR — pulling latest..."
    git -C "$DEPLOY_DIR" pull --ff-only
else
    [[ -n "$REPO_URL" ]] || die "Set REPO_URL env var to your GitHub repo (e.g. https://github.com/you/generic-backend.git)"
    log "Cloning $REPO_URL -> $DEPLOY_DIR..."
    git clone "$REPO_URL" "$DEPLOY_DIR"
fi

# ── 4. install Python dependencies ────────────────────────────────────────────
log "Installing Python dependencies..."
cd "$DEPLOY_DIR"
uv sync --no-dev

# ── 5. set up data directory and permissions ──────────────────────────────────
log "Setting up data directory..."
mkdir -p "$DEPLOY_DIR/data"
chown -R "$APP_USER":"$APP_USER" "$DEPLOY_DIR"

# ── 6. install and enable systemd service ────────────────────────────────────
log "Installing systemd service..."
cp "$DEPLOY_DIR/${SERVICE_NAME}.service" "/etc/systemd/system/${SERVICE_NAME}.service"
systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl restart "$SERVICE_NAME"
systemctl is-active --quiet "$SERVICE_NAME" && log "Service is running." || die "Service failed to start. Run: journalctl -u ${SERVICE_NAME} -n 50"

# ── 7. configure nginx reverse proxy ─────────────────────────────────────────
if [[ ! -f "$NGINX_CONF" ]]; then
    log "Writing nginx config (edit ServerName before going live)..."
    cat > "$NGINX_CONF" <<'NGINX'
server {
    listen 80;
    server_name _;   # replace _ with your domain name

    location / {
        proxy_pass         http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
    }
}
NGINX
    ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    nginx -t && systemctl reload nginx
    log "nginx configured. Visit http://<your-server-ip>/ to verify."
else
    log "nginx config already exists at $NGINX_CONF — skipping."
fi

log ""
log "Deployment complete!"
log "  App dir : $DEPLOY_DIR"
log "  Data dir: $DEPLOY_DIR/data"
log "  Service : systemctl status $SERVICE_NAME"
log "  Logs    : journalctl -u $SERVICE_NAME -f"
log ""
log "Next steps:"
log "  1. Point your domain DNS to this server's IP."
log "  2. Edit $NGINX_CONF and set 'server_name your.domain.com;'"
log "  3. Run: certbot --nginx -d your.domain.com   (install certbot first if needed)"
