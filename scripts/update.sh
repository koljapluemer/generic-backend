#!/usr/bin/env bash
# Update script for generic-backend — pull latest code and restart service.
# Run on the VPS as root:
#   sudo bash /opt/generic-backend/scripts/update.sh
set -euo pipefail

DEPLOY_DIR="/opt/generic-backend"
SERVICE_NAME="generic-backend"

log() { echo "[update] $*"; }
die() { echo "[update] ERROR: $*" >&2; exit 1; }

[[ "$EUID" -eq 0 ]] || die "Run as root (sudo bash scripts/update.sh)"
[[ -d "$DEPLOY_DIR/.git" ]] || die "$DEPLOY_DIR is not a git repo. Run deploy.sh first."

cd "$DEPLOY_DIR"

log "Pulling latest code..."
git pull --ff-only

log "Syncing dependencies..."
uv sync --no-dev

log "Restarting service..."
systemctl restart "$SERVICE_NAME"
systemctl is-active --quiet "$SERVICE_NAME" \
    && log "Service restarted successfully." \
    || die "Service failed to restart. Run: journalctl -u ${SERVICE_NAME} -n 50"

log "Update complete."
