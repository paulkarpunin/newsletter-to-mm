#!/bin/bash
set -e 

echo "==== Инициализация Zero-touch развертывания (Private Repo) ===="

# 1. Валидация прав доступа и наличия токена
if [ "$EUID" -ne 0 ]; then
  echo "[ОШИБКА] Скрипт развертывания должен быть запущен с правами root."
  exit 1
fi

if [ -z "$GH_TOKEN" ]; then
  echo "[ОШИБКА] Не задана переменная окружения GH_TOKEN для доступа к репозиторию."
  exit 1
fi

# Базовые переменные
REPO_RAW_URL="https://raw.githubusercontent.com/paulkarpunin/newsletter-to-mm/main"
INSTALL_DIR="/opt/mattermost_bot"
LOG_DIR="/var/log/mattermost_bot"
CRON_FILE="/etc/cron.d/mattermost_bot"

# Функция для авторизованной загрузки файлов
download_file() {
  local url="$1"
  local dest="$2"
  # Используем HTTP-заголовок Authorization для аутентификации в GitHub
  curl -sSL -H "Authorization: token $GH_TOKEN" "$url" -o "$dest"
}

# 2. Разрешение зависимостей уровня ОС
echo "[1/5] Проверка и установка системных зависимостей..."
apt-get update -qq
apt-get install -y python3 python3-requests > /dev/null

# 3. Подготовка файловой системы
echo "[2/5] Формирование структуры каталогов..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$LOG_DIR"

# 4. Транспорт данных из репозитория
echo "[3/5] Загрузка исполняемого кода..."
download_file "$REPO_RAW_URL/mattermost_sender.py" "$INSTALL_DIR/mattermost_sender.py"

if [ ! -f "$INSTALL_DIR/config.json" ]; then
    echo "[ИНФО] Боевой config.json не найден. Загрузка шаблона..."
    download_file "$REPO_RAW_URL/config.json.example" "$INSTALL_DIR/config.json"
else
    echo "[ИНФО] Обнаружен существующий config.json. Пропуск."
fi

# 5. Изоляция и безопасность
echo "[4/5] Настройка политик доступа..."
chmod 700 "$INSTALL_DIR"
chmod 700 "$INSTALL_DIR/mattermost_sender.py"
chmod 600 "$INSTALL_DIR/config.json"

# 6. Декларативная настройка расписания (Cron)
echo "[5/5] Регистрация расписания..."
cat <<EOF > "$CRON_FILE"
21 09 * * 1-5 root /usr/bin/python3 $INSTALL_DIR/mattermost_sender.py morning_status --config $INSTALL_DIR/config.json >> $LOG_DIR/execution.log 2>&1
EOF

chmod 644 "$CRON_FILE"
systemctl restart cron

echo "==== Установка успешно завершена ===="