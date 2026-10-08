#!/usr/bin/env bash
# Доставка статического ресурса на devops-vm
# Использование: scripts/deploy.sh [--dry-run]
set -euo pipefail

REMOTE="devops"
REMOTE_DIR="/var/www/devops-site"
SITE_URL="https://devops.local"
CA_CERT="${HOME}/devops.crt"
LOCAL_DIR="$(git rev-parse --show-toplevel)/site/"

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
fi

# Проверка 4: index.html существует
if [[ ! -f "${LOCAL_DIR}/index.html" ]]; then
  echo "Ошибка: site/index.html не найден" >&2
  exit 1
fi

# Проверка 5: нет незафиксированных изменений
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Ошибка: есть незафиксированные изменения" >&2
  exit 1
fi

RSYNC_OPTS=(-avz --delete --chmod=D755,F644 -e "ssh -o BatchMode=yes -o ConnectTimeout=5")
if [[ $DRY_RUN -eq 1 ]]; then
  rsync "${RSYNC_OPTS[@]}" --dry-run "${LOCAL_DIR}" "${REMOTE}:${REMOTE_DIR}/"
  exit 0
fi

rsync "${RSYNC_OPTS[@]}" "${LOCAL_DIR}" "${REMOTE}:${REMOTE_DIR}/"

# Проверка 7: доступность сайта
if ! curl -fs --cacert "${CA_CERT}" "${SITE_URL}" -o /dev/null; then
  echo "Ошибка: сайт недоступен" >&2
  exit 1
fi

echo "Деплой успешен: $(git rev-parse --short HEAD)"
