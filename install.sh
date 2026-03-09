#!/bin/bash
set -e 

echo "==== Инициализация Zero-touch развертывания (Private Repo) ===="

if [ "$EUID" -ne 0 ]; then
  echo "[ОШИБКА] Запустите с правами root."
  exit 1
fi

if [ -z "$GH_TOKEN" ]; then
  echo "[ОШИБКА] Переменная GH_TOKEN не найдена."
  exit 1
fi

REPO_RAW_URL="https://raw.githubusercontent.com/paulkarpunin/newsletter-to-mm/main"
INSTALL_DIR="/opt/mattermost_bot"
LOG_DIR="/var/log/mattermost_bot"
CRON_FILE="/etc/cron.d/mattermost_bot"

download_file() {
  local url="$1"
  local dest="$2"
  curl -sSL -H "Authorization: token $GH_TOKEN" "$url" -o "$dest"
}

echo "[1/5] Системные зависимости..."
apt-get update -qq
apt-get install -y python3 python3-requests > /dev/null

echo "[2/5] Структура каталогов..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$LOG_DIR"

echo "[3/5] Загрузка кода..."
download_file "$REPO_RAW_URL/mattermost_sender.py" "$INSTALL_DIR/mattermost_sender.py"
download_file "$REPO_RAW_URL/manager.py" "$INSTALL_DIR/manager.py"

if [ ! -f "$INSTALL_DIR/config.json" ]; then
    echo "[ИНФО] Загрузка шаблона конфигурации..."
    download_file "$REPO_RAW_URL/config.json.example" "$INSTALL_DIR/config.json"
fi

echo "[4/5] Политики доступа..."
chmod 700 "$INSTALL_DIR"
chmod 700 "$INSTALL_DIR/mattermost_sender.py"
chmod 700 "$INSTALL_DIR/manager.py"
chmod 600 "$INSTALL_DIR/config.json"

echo "[5/5] Инициализация системного планировщика..."
if [ ! -f "$CRON_FILE" ]; then
    echo "# Автоматически сгенерированное расписание для Mattermost Bot" > "$CRON_FILE"
fi
chmod 644 "$CRON_FILE"
systemctl restart cron

echo "==== Установка успешно завершена ===="
echo "[ДЕЙСТВИЕ] Для управления рассылками запустите: sudo /usr/bin/python3 $INSTALL_DIR/manager.py"