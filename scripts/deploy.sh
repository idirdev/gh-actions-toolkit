#!/usr/bin/env bash
# =============================================================================
# deploy.sh -- Deploy application to a VPS via SSH + SCP.
#
# Usage:
#   ./scripts/deploy.sh [staging|production]
#
# Required environment variables:
#   VPS_HOST     -- Server hostname or IP
#   VPS_USER     -- SSH username
#   APP_DIR      -- Remote application directory (e.g. /var/www/app)
#   PM2_APP_NAME -- PM2 process name (e.g. "my-api")
#
# Optional:
#   SSH_KEY_PATH -- Path to SSH private key (default: ~/.ssh/id_rsa)
# =============================================================================

set -euo pipefail

ENVIRONMENT="${1:-production}"
SSH_KEY="${SSH_KEY_PATH:-$HOME/.ssh/id_rsa}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------
for VAR in VPS_HOST VPS_USER APP_DIR PM2_APP_NAME; do
  if [[ -z "${!VAR:-}" ]]; then
    echo "Error: $VAR is not set."
    exit 1
  fi
done

if [[ ! -f "$SSH_KEY" ]]; then
  echo "Error: SSH key not found at $SSH_KEY"
  exit 1
fi

echo "==================================================="
echo " Deploying to ${ENVIRONMENT}"
echo " Host:    ${VPS_HOST}"
echo " User:    ${VPS_USER}"
echo " AppDir:  ${APP_DIR}"
echo " PM2:     ${PM2_APP_NAME}"
echo "==================================================="
echo ""

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
echo "[1/5] Building project..."
npm ci --omit=dev
npm run build

# ---------------------------------------------------------------------------
# Create tarball
# ---------------------------------------------------------------------------
echo "[2/5] Creating deployment tarball..."
TARBALL="deploy-${TIMESTAMP}.tar.gz"
tar -czf "$TARBALL" dist/ package.json package-lock.json

echo "  -> ${TARBALL} ($(du -h "$TARBALL" | cut -f1))"

# ---------------------------------------------------------------------------
# Upload
# ---------------------------------------------------------------------------
echo "[3/5] Uploading to server..."
scp -i "$SSH_KEY" -o StrictHostKeyChecking=no "$TARBALL" \
  "${VPS_USER}@${VPS_HOST}:/tmp/${TARBALL}"

# ---------------------------------------------------------------------------
# Deploy remotely
# ---------------------------------------------------------------------------
echo "[4/5] Executing remote deployment..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "${VPS_USER}@${VPS_HOST}" bash <<REMOTE
set -e

# Backup current version
BACKUP="${APP_DIR}_backup_${TIMESTAMP}"
echo "  -> Backing up to \$BACKUP"
cp -r "${APP_DIR}" "\$BACKUP" 2>/dev/null || true

# Extract new build
cd "${APP_DIR}"
tar -xzf "/tmp/${TARBALL}"

# Install production dependencies
npm ci --omit=dev

# Restart via PM2
pm2 restart "${PM2_APP_NAME}" || pm2 start dist/server.js --name "${PM2_APP_NAME}"

# Clean up tarball
rm -f "/tmp/${TARBALL}"

# Remove backups older than 7 days
find "$(dirname "${APP_DIR}")" -maxdepth 1 -name "*_backup_*" -mtime +7 -exec rm -rf {} + 2>/dev/null || true

echo "  -> Deployment successful!"
pm2 status "${PM2_APP_NAME}"
REMOTE

# ---------------------------------------------------------------------------
# Cleanup local
# ---------------------------------------------------------------------------
echo "[5/5] Cleaning up..."
rm -f "$TARBALL"

echo ""
echo "Deployment to ${ENVIRONMENT} complete!"
