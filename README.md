# Hysteria 2 — Полная инструкция

Быстрый, устойчивый к блокировкам прокси на базе протокола QUIC. Маскируется под обычный HTTPS-трафик.

---

## Содержание

- [Требования](#требования)
- [Способ 1: Автоматическая установка (скрипт)](#способ-1-автоматическая-установка-скрипт)
- [Способ 2: Ручная установка](#способ-2-ручная-установка)
- [Настройка клиентов](#настройка-клиентов)
- [Управление сервером](#управление-сервером)
- [Частые проблемы](#частые-проблемы)

---

## Требования

### Сервер (VPS)

| Параметр | Минимум |
|---|---|
| ОС | Ubuntu 20.04 / 22.04 / 24.04, Debian 11 / 12 |
| RAM | 512 MB |
| CPU | 1 ядро |
| Трафик | безлимит или от 1 ТБ |
| Расположение | за пределами РФ (Германия, Нидерланды, Финляндия — ближе = ниже пинг) |

Популярные хостинги: Hetzner, Aeza, PQ Hosting, Timeweb Cloud.

После покупки вы получите: **IP-адрес**, **логин** (обычно `root`), **пароль**.

### Подключение к серверу

**Windows** — скачайте [PuTTY](https://putty.org/) или используйте Windows Terminal:
```
ssh root@ВАШ_IP
```

**macOS / Linux** — откройте Терминал:
```
ssh root@ВАШ_IP
```

---

## Способ 1: Автоматическая установка (скрипт)

Самый простой вариант — одна команда, и прокси готов.

### Запуск

Подключитесь к серверу по SSH и выполните:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/vfxbro/hysteria2-install/master/hysteria2_install.sh)
```

### Что произойдёт

1. Скрипт проверит ОС и определит IP сервера
2. Предложит выбрать:
   - **Порт** (по умолчанию 443)
   - **Сайт для маскировки** (bing.com, google.com, apple.com или свой)
   - **Лимит скорости** (100 / 200 / 500 Mbps или без лимита)
3. Установит Hysteria 2, сгенерирует сертификат и пароль
4. Запустит сервер
5. Выдаст готовую **URI-ссылку** для вставки в клиент

### Пример вывода после установки

```
Данные для подключения:
  Протокол:    Hysteria 2
  Сервер:      123.456.789.0
  Порт:        443
  Пароль:      xK7m9...сгенерированный...
  SNI:         www.bing.com
  Insecure:    true

URI-ссылка (скопируйте в клиент):
hy2://xK7m9...@123.456.789.0:443?sni=www.bing.com&insecure=1#Hysteria2
```

### Повторный запуск

Если Hysteria уже установлена, скрипт покажет меню:

```
1) Показать данные для подключения
2) Переустановить / перенастроить
3) Удалить Hysteria 2
0) Выход
```

---

## Способ 2: Ручная установка

Для тех, кто хочет понимать каждый шаг.

### Шаг 1: Обновление системы

```bash
apt update && apt upgrade -y
```

### Шаг 2: Установка Hysteria 2

```bash
bash <(curl -fsSL https://get.hy2.sh/)
```

Проверьте установку:
```bash
hysteria version
```

### Шаг 3: Генерация TLS-сертификата

Самоподписанный сертификат (если нет домена):

```bash
openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) \
  -keyout /etc/hysteria/key.pem \
  -out /etc/hysteria/cert.pem \
  -subj "/CN=bing.com" \
  -days 3650
```

> Если есть домен — лучше использовать Let's Encrypt. Но самоподписанный тоже работает.

### Шаг 4: Генерация пароля

```bash
openssl rand -base64 24
```

Запишите результат — это пароль для подключения.

### Шаг 5: Создание конфигурации

```bash
nano /etc/hysteria/config.yaml
```

Вставьте (замените `ВАШ_ПАРОЛЬ`):

```yaml
listen: :443

tls:
  cert: /etc/hysteria/cert.pem
  key: /etc/hysteria/key.pem

auth:
  type: password
  password: ВАШ_ПАРОЛЬ

masquerade:
  type: proxy
  proxy:
    url: https://www.bing.com
    rewriteHost: true

bandwidth:
  up: 100 mbps
  down: 100 mbps

ignoreClientBandwidth: false
```

Сохраните: `Ctrl+O` → `Enter` → `Ctrl+X`

#### Что значит каждая строка

| Параметр | Описание |
|---|---|
| `listen: :443` | Слушает UDP порт 443 (выглядит как HTTPS) |
| `tls` | Путь к сертификатам шифрования |
| `auth` | Пароль для подключения клиентов |
| `masquerade` | Маскировка — при обращении к IP в браузере покажется Bing |
| `bandwidth` | Лимит скорости на каждого клиента |

### Шаг 6: Запуск

```bash
systemctl enable hysteria-server
systemctl start hysteria-server
```

Проверьте:
```bash
systemctl status hysteria-server
```

Должно быть **active (running)**.

### Шаг 7: Базовая безопасность

```bash
# Сменить пароль root
passwd

# Автообновления безопасности
apt install unattended-upgrades -y
dpkg-reconfigure -plow unattended-upgrades
```

---

## Настройка клиентов

### URI-ссылка

Самый простой способ — сформировать ссылку и вставить в любой клиент:

```
hy2://ВАШ_ПАРОЛЬ@ВАШ_IP:443?sni=www.bing.com&insecure=1#MyProxy
```

> При автоматической установке скрипт выдаст готовую ссылку.

### Android — Hiddify

1. Установите **Hiddify** из Google Play
2. Нажмите **+** → вставьте URI-ссылку
3. Или добавьте вручную:
   - Тип: **Hysteria2**
   - Адрес: `ВАШ_IP`
   - Порт: `443`
   - Пароль: из конфига
   - SNI: `www.bing.com`
   - Allow Insecure: **Вкл**
4. Подключитесь

### iOS — Shadowrocket / Stash

1. Установите **Shadowrocket** (платный) или **Stash**
2. Добавьте сервер:
   - Тип: **Hysteria2**
   - Адрес: `ВАШ_IP`
   - Порт: `443`
   - Пароль: из конфига
   - SNI: `www.bing.com`
   - Skip Cert Verify: **On**

### Windows / macOS — Hiddify

1. Скачайте [Hiddify](https://github.com/hiddify/hiddify-app/releases)
2. Вставьте URI-ссылку или добавьте вручную:
   - Тип: **Hysteria2**
   - Server: `ВАШ_IP`
   - Port: `443`
   - Password: из конфига
   - SNI: `www.bing.com`
   - Insecure: `true`

### Проверка подключения

1. Подключитесь через клиент
2. Откройте [2ip.ru](https://2ip.ru) или [ifconfig.me](https://ifconfig.me)
3. IP должен показывать IP вашего сервера, а не домашний

---

## Управление сервером

| Команда | Описание |
|---|---|
| `systemctl status hysteria-server` | Статус сервера |
| `systemctl restart hysteria-server` | Перезапуск |
| `systemctl stop hysteria-server` | Остановка |
| `journalctl -u hysteria-server -f` | Логи в реальном времени |
| `nano /etc/hysteria/config.yaml` | Редактировать конфиг |

### Структура файлов

```
/etc/hysteria/
├── config.yaml    ← конфигурация
├── cert.pem       ← TLS-сертификат
└── key.pem        ← TLS-ключ
```

---

## Частые проблемы

| Проблема | Решение |
|---|---|
| Не подключается | Проверьте что UDP 443 не заблокирован хостером |
| `connection refused` | `systemctl status hysteria-server` — смотрите логи |
| Медленная скорость | Увеличьте `bandwidth` в конфиге или уберите лимит |
| Сертификат истёк | Перегенерируйте сертификат и перезапустите сервис |
| Логи показывают ошибки | `journalctl -u hysteria-server -e --no-pager` |

---

## Лицензия

MIT — используйте свободно.
