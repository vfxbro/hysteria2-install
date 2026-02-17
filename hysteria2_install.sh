#!/bin/bash

# ============================================
#  Hysteria 2 — установка в 1 клик
#  Поддержка: Ubuntu 20.04 / 22.04 / 24.04
#            Debian 11 / 12
# ============================================

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════╗"
    echo "║     Hysteria 2 — Установка прокси       ║"
    echo "║          Скрипт в 1 клик             ║"
    echo "╚══════════════════════════════════════╝"
    echo -e "${NC}"
}

print_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
print_err() { echo -e "${RED}[ОШИБКА]${NC} $1"; }

# Проверка root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        print_err "Запустите скрипт от root: sudo bash $0"
        exit 1
    fi
}

# Проверка ОС
check_os() {
    if ! grep -qiE 'ubuntu|debian' /etc/os-release 2>/dev/null; then
        print_err "Поддерживаются только Ubuntu и Debian"
        exit 1
    fi
    print_ok "ОС: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
}

# Получение внешнего IP
get_ip() {
    SERVER_IP=$(curl -s4 ifconfig.me || curl -s4 icanhazip.com || curl -s4 ip.sb)
    if [ -z "$SERVER_IP" ]; then
        print_err "Не удалось определить внешний IP"
        exit 1
    fi
    print_ok "IP сервера: $SERVER_IP"
}

# Генерация пароля
generate_password() {
    PASSWORD=$(openssl rand -base64 24)
    print_ok "Пароль сгенерирован"
}

# Меню выбора порта
choose_port() {
    echo ""
    echo -e "${CYAN}Выберите порт для Hysteria 2:${NC}"
    echo "  1) 443  — стандартный HTTPS (рекомендуется)"
    echo "  2) Ввести свой порт"
    echo ""
    read -rp "Ваш выбор [1]: " port_choice
    port_choice=${port_choice:-1}

    case $port_choice in
        1) PORT=443 ;;
        2)
            read -rp "Введите порт (1024-65535): " custom_port
            if [[ "$custom_port" =~ ^[0-9]+$ ]] && [ "$custom_port" -ge 1024 ] && [ "$custom_port" -le 65535 ]; then
                PORT=$custom_port
            else
                print_err "Некорректный порт, используем 443"
                PORT=443
            fi
            ;;
        *) PORT=443 ;;
    esac
    print_ok "Порт: $PORT"
}

# Меню выбора маскировки
choose_masquerade() {
    echo ""
    echo -e "${CYAN}Сайт для маскировки (что увидит цензор):${NC}"
    echo "  1) microsoft.com (рекомендуется)"
    echo "  2) google.com"
    echo "  3) apple.com"
    echo "  4) Ввести свой"
    echo ""
    read -rp "Ваш выбор [1]: " mask_choice
    mask_choice=${mask_choice:-1}

    case $mask_choice in
        1) MASQ_URL="https://www.microsoft.com" ;;
        2) MASQ_URL="https://www.google.com" ;;
        3) MASQ_URL="https://www.apple.com" ;;
        4)
            read -rp "Введите URL (https://...): " custom_url
            if [[ "$custom_url" =~ ^https:// ]]; then
                MASQ_URL="$custom_url"
            else
                print_err "URL должен начинаться с https://, используем microsoft.com"
                MASQ_URL="https://www.microsoft.com"
            fi
            ;;
        *) MASQ_URL="https://www.microsoft.com" ;;
    esac

    # Извлекаем домен для SNI
    MASQ_DOMAIN=$(echo "$MASQ_URL" | sed 's|https://||' | sed 's|/.*||')
    print_ok "Маскировка: $MASQ_URL"
}

# Выбор лимита скорости
choose_bandwidth() {
    echo ""
    echo -e "${CYAN}Лимит скорости на клиента:${NC}"
    echo "  1) 100 Mbps"
    echo "  2) 200 Mbps"
    echo "  3) 500 Mbps"
    echo "  4) Без лимита"
    echo ""
    read -rp "Ваш выбор [1]: " bw_choice
    bw_choice=${bw_choice:-1}

    case $bw_choice in
        1) BW_UP="100 mbps"; BW_DOWN="100 mbps" ;;
        2) BW_UP="200 mbps"; BW_DOWN="200 mbps" ;;
        3) BW_UP="500 mbps"; BW_DOWN="500 mbps" ;;
        4) BW_UP="0 mbps"; BW_DOWN="0 mbps" ;;
        *) BW_UP="100 mbps"; BW_DOWN="100 mbps" ;;
    esac
    print_ok "Скорость: up=$BW_UP / down=$BW_DOWN"
}

# Установка зависимостей
install_deps() {
    echo ""
    print_warn "Обновление системы и установка зависимостей..."
    apt update -qq > /dev/null 2>&1
    apt install -y -qq curl openssl > /dev/null 2>&1
    print_ok "Зависимости установлены"
}

# Установка Hysteria 2
install_hysteria() {
    echo ""
    print_warn "Установка Hysteria 2..."
    if command -v hysteria &> /dev/null; then
        print_ok "Hysteria уже установлена, обновляем..."
    fi
    bash <(curl -fsSL https://get.hy2.sh/) > /dev/null 2>&1
    print_ok "Hysteria 2 $(hysteria version 2>/dev/null | grep Version | awk '{print $2}') установлена"
}

# Генерация сертификата
generate_cert() {
    echo ""
    print_warn "Генерация TLS-сертификата..."
    mkdir -p /etc/hysteria
    openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) \
        -keyout /etc/hysteria/key.pem \
        -out /etc/hysteria/cert.pem \
        -subj "/CN=$MASQ_DOMAIN" \
        -days 3650 2>/dev/null
    chmod 644 /etc/hysteria/cert.pem
    chmod 600 /etc/hysteria/key.pem
    print_ok "Сертификат создан (срок: 10 лет)"
}

# Создание конфигурации
create_config() {
    echo ""
    print_warn "Создание конфигурации..."

    cat > /etc/hysteria/config.yaml << EOF
listen: :${PORT}

tls:
  cert: /etc/hysteria/cert.pem
  key: /etc/hysteria/key.pem

auth:
  type: password
  password: ${PASSWORD}

masquerade:
  type: proxy
  proxy:
    url: ${MASQ_URL}
    rewriteHost: true

bandwidth:
  up: ${BW_UP}
  down: ${BW_DOWN}

ignoreClientBandwidth: false
EOF

    chmod 600 /etc/hysteria/config.yaml
    print_ok "Конфигурация создана"
}

# Запуск сервиса
start_service() {
    echo ""
    print_warn "Запуск Hysteria 2..."
    systemctl enable hysteria-server > /dev/null 2>&1
    systemctl restart hysteria-server
    sleep 2

    if systemctl is-active --quiet hysteria-server; then
        print_ok "Hysteria 2 запущена и работает!"
    else
        print_err "Не удалось запустить. Логи:"
        journalctl -u hysteria-server -n 20 --no-pager
        exit 1
    fi
}

# Вывод результата
print_result() {
    URI="hy2://${PASSWORD}@${SERVER_IP}:${PORT}?sni=${MASQ_DOMAIN}&insecure=1#Hysteria2"

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         УСТАНОВКА ЗАВЕРШЕНА УСПЕШНО!             ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Данные для подключения:${NC}"
    echo -e "  Протокол:    ${GREEN}Hysteria 2${NC}"
    echo -e "  Сервер:      ${GREEN}${SERVER_IP}${NC}"
    echo -e "  Порт:        ${GREEN}${PORT}${NC}"
    echo -e "  Пароль:      ${GREEN}${PASSWORD}${NC}"
    echo -e "  SNI:         ${GREEN}${MASQ_DOMAIN}${NC}"
    echo -e "  Insecure:    ${GREEN}true${NC}"
    echo ""
    echo -e "${CYAN}URI-ссылка (скопируйте в клиент):${NC}"
    echo -e "${YELLOW}${URI}${NC}"
    echo ""
    echo -e "${CYAN}Клиенты:${NC}"
    echo "  Android:     Hiddify (Google Play)"
    echo "  iOS:         Shadowrocket / Stash"
    echo "  Windows/Mac: Hiddify (github.com/hiddify/hiddify-app)"
    echo ""
    echo -e "${CYAN}Управление:${NC}"
    echo "  Статус:      systemctl status hysteria-server"
    echo "  Перезапуск:  systemctl restart hysteria-server"
    echo "  Логи:        journalctl -u hysteria-server -f"
    echo "  Конфиг:      /etc/hysteria/config.yaml"
    echo ""

    # Сохраняем данные в файл
    cat > /root/hysteria2_info.txt << EOF
=== Hysteria 2 ===
Сервер:   ${SERVER_IP}
Порт:     ${PORT}
Пароль:   ${PASSWORD}
SNI:      ${MASQ_DOMAIN}

URI: ${URI}

Конфиг: /etc/hysteria/config.yaml
EOF
    chmod 600 /root/hysteria2_info.txt
    print_ok "Данные сохранены в /root/hysteria2_info.txt"
}

# --- Управление существующей установкой ---

show_info() {
    if [ -f /root/hysteria2_info.txt ]; then
        cat /root/hysteria2_info.txt
    else
        print_err "Файл с данными не найден"
    fi
}

add_client() {
    # В Hysteria 2 с password-auth все клиенты используют один пароль
    print_warn "Hysteria 2 с типом auth: password — один пароль для всех."
    echo "Просто передайте URI-ссылку новому пользователю."
    show_info
}

uninstall() {
    echo ""
    read -rp "Вы уверены? Hysteria 2 будет полностью удалена [y/N]: " confirm
    if [[ "$confirm" =~ ^[yYдД]$ ]]; then
        systemctl stop hysteria-server 2>/dev/null
        systemctl disable hysteria-server 2>/dev/null
        bash <(curl -fsSL https://get.hy2.sh/) --remove > /dev/null 2>&1
        rm -rf /etc/hysteria
        rm -f /root/hysteria2_info.txt
        print_ok "Hysteria 2 удалена"
    else
        print_warn "Отменено"
    fi
}

# --- Главное меню ---

main_menu() {
    print_banner

    # Если Hysteria уже установлена — показываем меню управления
    if command -v hysteria &> /dev/null && systemctl is-active --quiet hysteria-server 2>/dev/null; then
        echo -e "${GREEN}Hysteria 2 уже установлена и работает${NC}"
        echo ""
        echo "  1) Показать данные для подключения"
        echo "  2) Переустановить / перенастроить"
        echo "  3) Удалить Hysteria 2"
        echo "  0) Выход"
        echo ""
        read -rp "Выбор: " menu_choice

        case $menu_choice in
            1) show_info ;;
            2) fresh_install ;;
            3) uninstall ;;
            0) exit 0 ;;
            *) print_err "Неверный выбор"; exit 1 ;;
        esac
    else
        fresh_install
    fi
}

fresh_install() {
    check_os
    get_ip
    generate_password
    choose_port
    choose_masquerade
    choose_bandwidth
    install_deps
    install_hysteria
    generate_cert
    create_config
    start_service
    print_result
}

# --- Запуск ---
check_root
main_menu
