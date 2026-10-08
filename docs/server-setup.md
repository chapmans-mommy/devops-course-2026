# Конфигурация виртуальной машины devops-vm

## 1. Параметры машины

| Параметр | Значение |
|----------|----------|
| Имя VM | devops-vm |
| ОС | Ubuntu Server 24.04 LTS |
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
| devops | sudo, devops | SSH-ключ ed25519 | Основной администратор |

## 5. Служба SSH

| Параметр | Значение |
|----------|----------|
| Порт | 2222 |
| Конфиг | /etc/ssh/sshd_config.d/99-hardening.conf |
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
| 02-keys-configured | После настройки SSH-ключей |
| 03-ssh-hardened | После усиления SSH и UFW |

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
