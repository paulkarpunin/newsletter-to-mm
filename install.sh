#!/bin/bash
# Строгий режим: прерывание выполнения при любой ошибке (включая неперехваченные статусы внутри пайплайна)
set -eo pipefail 

echo "==== Инициализация Zero-touch развертывания (Private Repo) ===="

# 1. Валидация базовых условий исполнения
if [ "$EUID" -ne 0 ]; then
  echo "[ОШИБКА] Скрипт должен быть запущен с правами root (sudo)."
  exit 1
fi

if [ -z "$GH_TOKEN" ]; then
  echo "[ОШИБКА] Переменная окружения GH_TOKEN не найдена. Доступ к приватному репозиторию невозможен."
  exit 1
fi

# Архитектурные константы
REPO_RAW_URL="https://raw.githubusercontent.com/paulkarpunin/newsletter-to-mm/main"
INSTALL_DIR="/opt/mattermost_bot"
LOG_DIR="/var/log/mattermost_bot"
CRON_FILE="/etc/cron.d/mattermost_bot"

# Функция безопасного транспорта с авторизацией
download_file() {
  local url="$1"
  local dest="$2"
  curl -sSL -H "Authorization: token $GH_TOKEN" "$url" -o "$dest"
}

# 2. Разрешение системных зависимостей
echo "[1/6] Установка системных зависимостей (Python3 & Requests)..."
apt-get update -qq
apt-get install -y python3 python3-requests > /dev/null

# 3. Подготовка файловой системы
echo "[2/6] Формирование структуры каталогов..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$LOG_DIR"

# 4. Транспорт логики и конфигурации
echo "[3/6] Загрузка исполняемого кода из репозитория..."
download_file "$REPO_RAW_URL/mattermost_sender.py" "$INSTALL_DIR/mattermost_sender.py"
download_file "$REPO_RAW_URL/manager.py" "$INSTALL_DIR/manager.py"

# Декларативное управление конфигурацией: не затираем боевые данные при обновлениях
if [ ! -f "$INSTALL_DIR/config.json" ]; then
    echo "[ИНФО] Загрузка шаблона конфигурации (config.json.example)..."
    download_file "$REPO_RAW_URL/config.json.example" "$INSTALL_DIR/config.json"
else
    echo "[ИНФО] Боевой config.json уже существует. Пропуск перезаписи."
fi

# 5. Изоляция и безопасность (Принцип наименьших привилегий)
echo "[4/6] Применение политик безопасности (chmod)..."
chmod 700 "$INSTALL_DIR"
chmod 700 "$INSTALL_DIR/mattermost_sender.py"
chmod 700 "$INSTALL_DIR/manager.py"
chmod 600 "$INSTALL_DIR/config.json"

echo "[6/6] Создание системной команды 'gomattermost'..."
cat <<EOF > /usr/local/bin/gomattermost
#!/bin/bash
sudo PYTHONIOENCODING=utf-8 /usr/bin/python3 $INSTALL_DIR/manager.py
EOF
chmod +x /usr/local/bin/gomattermost
systemctl restart cron

# 7. Интеграция пользовательского интерфейса (CLI Wrapper)
echo "[6/6] Создание системной команды 'gomattermost'..."
cat <<EOF > /usr/local/bin/gomattermost
#!/bin/bash
# Обертка для запуска менеджера с правами суперпользователя
sudo /usr/bin/python3 $INSTALL_DIR/manager.py
EOF
chmod +x /usr/local/bin/gomattermost

echo "==== Развертывание успешно завершено ===="
echo "[ДЕЙСТВИЕ] Для управления рассылками введите команду: gomattermost"