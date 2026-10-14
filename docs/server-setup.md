# Конфигурация виртуальной машины devops-vm

## 1. Параметры машины

| Параметр | Значение |
|----------|----------|
| Имя VM | devops-vm |
| ОС | Ubuntu Server 26.04.1 LTS |
| RAM | 2048 МБ |
| Ядра CPU | 2 |
| Диск | 25 ГБ (динамически расширяемый) |
| Гипервизор | VirtualBox 7.x |

## 2. Сетевые интерфейсы

| Адаптер | Тип | Адрес | Назначение |
|---------|-----|-------|------------|
| Адаптер 1 | NAT | 10.0.2.15 | Доступ в интернет, проброс SSH |
| Адаптер 2 | Host-only (vboxnet0) | 192.168.56.101 | Доступ с хоста, веб-сервер |

## 3. Правило проброса портов

| Параметр | Значение |
|----------|----------|
| Имя правила | SSH |
| Протокол | TCP |
| Порт хоста | 2222 |
| Порт гостя | 2222 |
| IP хоста | (пусто) |
| IP гостя | (пусто) |

## 4. Учётные записи

| Пользователь | Группы | Аутентификация | Назначение |
|--------------|--------|----------------|------------|
| student | sudo, adm | Пароль | Первичная настройка |
| devops | sudo, users, docker | SSH-ключ ed25519 | Основной администратор |

## 5. Служба SSH

| Параметр | Значение |
|----------|----------|
| Порт | 2222 |
| Конфиг | /etc/ssh/sshd_config.d/99-hardening.conf; PasswordAuthentication=no также в 50-cloud-init.conf |
| PermitRootLogin | no |
| PasswordAuthentication | no |
| PubkeyAuthentication | yes |
| PermitEmptyPasswords | no |
| MaxAuthTries | 3 |
| LoginGraceTime | 30 |
| AllowUsers | devops |
| X11Forwarding | no |
| ClientAliveInterval | 300 |
| ClientAliveCountMax | 2 |

## 6. Правила межсетевого экрана (UFW)

| Политика / Правило | Значение |
|---------------------|----------|
| Default incoming | deny |
| Default outgoing | allow |
| Allow 2222/tcp (LIMIT) | SSH rate-limited |
| Allow 80/tcp | HTTP |
| Allow 443/tcp | HTTPS |

## 7. Снимки состояния

| Имя снимка | Момент создания |
|------------|-----------------|
| 01-clean-install | После установки ОС |
| 04-nginx-https | После настройки Nginx и HTTPS |
| 05-docker-compose | После выполнения контейнеризации и проверок |

## 8. Веб-сервер

| Параметр | Значение |
|----------|----------|
| Пакет | nginx (установлен через `apt install nginx`) |
| Конфигурация ресурса | `/etc/nginx/sites-available/devops-site` |
| Активная ссылка | `/etc/nginx/sites-enabled/devops-site` |
| Стандартный ресурс | отключён (`/etc/nginx/sites-enabled/default` удалён) |
| Каталог ресурса | `/var/www/devops-site` |
| Владелец каталога | `devops:devops` |
| Права каталога | `755` (drwxr-xr-x) |
| Права файлов | `644` (rw-r--r--) |
| Сертификат | `/etc/ssl/certs/devops.crt`, права `644`, владелец `root:root` |
| Закрытый ключ | `/etc/ssl/private/devops.key`, права `600`, владелец `root:root` |
| Команда формирования сертификата | `sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/devops.key -out /etc/ssl/certs/devops.crt -subj "/CN=devops.local" -addext "subjectAltName=DNS:devops.local"` |
| Срок действия сертификата | 365 дней |
| Перенаправление HTTP → HTTPS | блок `server` с `return 301 https://$host$request_uri` |
| Порт HTTP | 80 (редирект) |
| Порт HTTPS | 443 (TLS) |
| Доставка содержимого | `rsync -avz --delete --chmod=D755,F644 site/ devops:/var/www/devops-site/` |

## 9. Контейнеризация

Docker Engine Community 29.9.0 и Docker Compose v5.6.0 установлены из официального APT-репозитория Docker для Ubuntu 26.04 (resolute), архитектура amd64. Установлены пакеты docker-ce, docker-ce-cli, containerd.io, docker-buildx-plugin и docker-compose-plugin. Пакет docker.io не используется.

Восстановление установки:

```bash
sudo apt update
sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
sudo tee /etc/apt/sources.list.d/docker.sources <<'EOF'
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: resolute
Components: stable
Architectures: amd64
Signed-By: /etc/apt/keyrings/docker.asc
EOF
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker devops
# Далее начать новую SSH-сессию
```

Единственный дополнительный участник группы docker — devops (UID 1001); он также входит в sudo и users. Членство в docker фактически даёт административные права на хост, поэтому учётные записи без sudo не добавляются.

Исходный проект: каталог app в репозитории devops-course-2026. Расположение на сервере: /home/devops/app. Доставка с Windows выполняется MSYS2 rsync с предварительным --dry-run, флагами --delete и --exclude=.env. SSH: devops, порт 2222, ключ; хостовая сеть 192.168.56.101 и проброс 127.0.0.1:2222.

Секреты хранятся только на сервере: /home/devops/app/.env, владелец devops:devops, права 600. Файл исключён через .gitignore и app/.dockerignore. В Git хранится только .env.example с заглушкой change_me. Для нового развёртывания:

```bash
cd ~/app
cp .env.example .env
chmod 600 .env
sed -i "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$(openssl rand -hex 16)/" .env
docker compose up -d --build
```

Не перегенерировать пароль в существующем .env без согласованного изменения пароля в PostgreSQL: POSTGRES_PASSWORD применяется при первичной инициализации пустого тома.

Контейнер app-app-1 использует devops-app:1.0, Gunicorn на 5000, USER app (UID/GID 999). На хосте опубликован только 127.0.0.1:5000:5000. Контейнер app-db-1 использует postgres:16-alpine; порт 5432 наружу не опубликован. Оба сервиса в bridge-сети app_backend; DB_HOST=db разрешается встроенным DNS Docker. depends_on: condition: service_healthy ожидает pg_isready.

Именованный том app_db_data смонтирован в /var/lib/postgresql/data. docker compose down сохраняет том и счётчик; down -v удаляет базу. После учебного опыта том создан заново и сохранён. Оба сервиса имеют restart: unless-stopped.

Обратный прокси: /etc/nginx/sites-available/devops-site, активная ссылка /etc/nginx/sites-enabled/devops-site. В HTTPS-блок добавлено:

```nginx
    location /app/ {
        proxy_pass http://127.0.0.1:5000/;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
```

Статический location / и каталог /var/www/devops-site сохранены. HTTPS принимает 443; HTTP 80 перенаправляется на HTTPS. Завершающий / в proxy_pass преобразует /app/health в /health. Проверка и применение: sudo nginx -t && sudo systemctl reload nginx. Журнал ошибок: /var/log/nginx/devops-site.error.log. Конфигурация Nginx сохранена в config/nginx/devops-site репозитория.

Аудит: /home/devops/scripts/audit.sh, раздел [5]. Проверяет active службы Docker, healthy app-db-1, отсутствие внешних сокетов 5000/5432 (включая IPv6) и права .env=600. Запуск с sudo: sudo bash ~/scripts/audit.sh; echo $?. Контроль с публикацией 5000:5000 возвращает 1; после восстановления loopback — 0.

Снимки VirtualBox 01-clean-install и 04-nginx-https сохранены; итоговая конфигурация работы №7 сохранена в 05-docker-compose. Проект, том и снимки не удаляются после работы.

После автоматического обновления Ubuntu новое ядро 7.0.0-38-generic не обеспечило успешную загрузку этой VM. Проверено рабочее ядро 7.0.0-34-generic. Оно выбрано в /etc/default/grub.d/99-devops-vm-kernel.cfg через GRUB_DEFAULT="Advanced options for Ubuntu>Ubuntu, with Linux 7.0.0-34-generic" и update-grub. Файл сохранён в config/grub репозитория. Для восстановления скопировать его в /etc/default/grub.d/ и выполнить sudo update-grub. Новое ядро оставлено установленным; причина несовместимости требует отдельной диагностики.
