#!/usr/bin/env bash
# PayGate live deploy (a27pay.com, PAYGATE_ENVIRONMENT=live). Run after every
# push to main, for any change (screens, PHP code, database):
#
#   bash <APP_DIR>/scripts/deploy-live.sh
#
# Set APP_USER and APP_DIR below to the live server's site user and folder
# when the server is set up (see the deployment steps); the script refuses to
# run until then. It pulls main, installs packages, rebuilds the screens,
# backs up and migrates the database (as the owner login), refreshes Laravel's
# caches and restarts the web server and workers.
set -euo pipefail

APP_USER=a27pay
APP_DIR=/home/$APP_USER/public_html/a27pay_com

# Live database, its logins and the live services. They differ from a27pay.tech
# (database paygate, services paygate-*), which runs on the same server.
DB_NAME=a27pay_live
DB_OWNER=a27pay_live_owner
DB_APP=a27pay_live_app
SERVICE=a27pay-live

if [[ "$APP_USER" == CHANGE_ME* || "$APP_DIR" == *CHANGE_ME* ]]; then
    echo "Set APP_USER and APP_DIR at the top of scripts/deploy-live.sh first." >&2
    exit 1
fi

# Always run as the site user (never as root: files would become root's).
if [ "$(id -u)" -eq 0 ]; then
    exec sudo -u "$APP_USER" -H bash "$APP_DIR/scripts/deploy-live.sh" "$@"
fi

source "$APP_DIR/.server/env.sh"
source "$PAYGATE/.deploy.env"
cd "$PAYGATE_APP"

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$1"; }

# 1. Pull, then start again with the freshly pulled copy of this script.
if [ "${1:-}" != "--pulled" ]; then
    step "Pulling main"
    if [ -n "$(git status --short --untracked-files=no)" ]; then
        echo "Stopped: files on the server were changed by hand. Send this list to the developer:"
        git status --short --untracked-files=no
        exit 1
    fi
    git pull --ff-only origin main
    exec bash "$PAYGATE_APP/scripts/deploy-live.sh" --pulled
fi

# If anything below fails, don't leave the site on the maintenance page.
trap 'php artisan up >/dev/null 2>&1 || true; echo; echo "DEPLOY FAILED at the step above. Send the output to the developer."' ERR

step "PHP packages"
composer install --no-dev --optimize-autoloader --no-interaction

step "Building the screens"
npm ci --no-audit --no-fund
npm run build

step "Database backup"
BACKUP="$PAYGATE/backups/before-deploy-$(date +%F-%H%M).dump"
pg_dump -h 127.0.0.1 -p 5433 -U "$DB_OWNER" -Fc "$DB_NAME" > "$BACKUP"
echo "Saved $BACKUP"

step "Database changes"
php artisan down --retry=30 || true
php artisan config:clear   # migrations must use the owner login below, not the cached app login
DB_USERNAME="$DB_OWNER" DB_PASSWORD="$DB_OWNER_PASSWORD" php artisan migrate --force
psql "host=127.0.0.1 port=5433 dbname=$DB_NAME user=$DB_OWNER" -q -v app_role="$DB_APP" -f database/sql/app-privileges.sql

step "API keys this server would refuse (live / test)"
php artisan paygate:key-environments || true

step "Laravel caches"
php artisan config:cache
php artisan route:clear
php artisan event:cache
php artisan view:cache
php artisan up

step "Restarting web server and workers"
sudo /usr/bin/systemctl restart "$SERVICE-web"
sudo /usr/bin/systemctl restart "$SERVICE-horizon"
sudo /usr/bin/systemctl restart "$SERVICE-scheduler"

step "Done"
echo "Deployed $(git log -1 --oneline)"
php artisan migrate:status | tail -1
echo "Open https://a27pay.com and press Ctrl+Shift+R (Cmd+Shift+R on Mac) to load the new screens."
