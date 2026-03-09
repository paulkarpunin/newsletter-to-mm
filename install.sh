#!/bin/bash
set -eo pipefail 

echo "==== Инициализация развертывания (Public Repo) ===="

if [ "$EUID" -ne 0 ]; then
  echo "[ОШИБКА] Запустите с правами root (sudo)."
  exit 1
fi

# Константы
REPO_RAW_URL="https://raw.githubusercontent.com/paulkarpunin/newsletter-to-mm/main"
INSTALL_DIR="/opt/mattermost_bot"
LOG_DIR="/var/log/mattermost_bot"
CRON_FILE="/etc/cron.d/mattermost_bot"

# Теперь скачивание не требует токена
download_file() {
  curl -sSL "$1" -o "$2"
}

echo "[1/6] Установка зависимостей..."
apt-get update -qq && apt-get install -y python3 python3-requests > /dev/null

echo "[2/6] Создание директорий..."
mkdir -p "$INSTALL_DIR" "$LOG_DIR"

echo "[3/6] Загрузка кода..."
download_file "$REPO_RAW_URL/mattermost_sender.py" "$INSTALL_DIR/mattermost_sender.py"
download_file "$REPO_RAW_URL/manager.py" "$INSTALL_DIR/manager.py"

if [ ! -f "$INSTALL_DIR/config.json" ]; then
    download_file "$REPO_RAW_URL/config.json.example" "$INSTALL_DIR/config.json"
fi

echo "[4/6] Настройка прав..."
chmod 700 "$INSTALL_DIR" "$INSTALL_DIR/mattermost_sender.py" "$INSTALL_DIR/manager.py"
chmod 600 "$INSTALL_DIR/config.json"

echo "[5/6] Настройка планировщика..."
[ ! -f "$CRON_FILE" ] && echo "# Mattermost Bot Schedule" > "$CRON_FILE"
chmod 644 "$CRON_FILE"
systemctl restart cron

echo "[6/6] Создание команды gomattermost..."
cat <<EOF > /usr/local/bin/gomattermost
#!/bin/bash
sudo PYTHONIOENCODING=utf-8 /usr/bin/python3 $INSTALL_DIR/manager.py
EOF
chmod +x /usr/local/bin/gomattermost

echo "==== Установка успешно завершена! ===="
echo "Используйте команду: gomattermost"