#!/bin/bash
# Строгий режим: остановка при любой ошибке
set -e 

# Базовые переменные
REPO_RAW_URL="https://raw.githubusercontent.com/paulkarpunin/newsletter-to-mm/main"
INSTALL_DIR="/opt/mattermost_bot"
LOG_DIR="/var/log/mattermost_bot"
CRON_FILE="/etc/cron.d/mattermost_bot"

echo "==== Инициализация Zero-touch развертывания ===="

# 1. Валидация прав доступа
if [ "$EUID" -ne 0 ]; then
  echo "[ОШИБКА] Скрипт развертывания должен быть запущен с правами root (sudo)."
  exit 1
fi

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
curl -sSL "$REPO_RAW_URL/mattermost_sender.py" -o "$INSTALL_DIR/mattermost_sender.py"

if [ ! -f "$INSTALL_DIR/config.json" ]; then
    echo "[ИНФО] Боевой config.json не найден. Загрузка шаблона..."
    curl -sSL "$REPO_RAW_URL/config.json.example" -o "$INSTALL_DIR/config.json"
else
    echo "[ИНФО] Обнаружен существующий config.json. Пропуск."
fi

# 5. Изоляция и безопасность
echo "[4/5] Настройка политик доступа..."
chmod 700 "$INSTALL_DIR"
chmod 700 "$INSTALL_DIR/mattermost_sender.py"
chmod 600 "$INSTALL_DIR/config.json"

# 6. Декларативная настройка расписания (Cron)
echo "[5/5] Регистрация расписания в системном планировщике..."
# Обратите внимание: синтаксис файлов в /etc/cron.d/ требует указания пользователя (root)
cat <<EOF > "$CRON_FILE"
# Автоматически сгенерированное расписание для Mattermost Bot
# Запуск профиля morning_status с Пн по Пт в 09:21
21 09 * * 1-5 root /usr/bin/python3 $INSTALL_DIR/mattermost_sender.py morning_status --config $INSTALL_DIR/config.json >> $LOG_DIR/execution.log 2>&1
EOF

# Права на файл cron должны быть строго 644, иначе процесс cron его проигнорирует
chmod 644 "$CRON_FILE"

# Перезагрузка службы для немедленного применения
systemctl restart cron

echo "==== Установка успешно завершена ===="
echo "[ДЕЙСТВИЕ] Отредактируйте конфигурацию для активации логики: nano $INSTALL_DIR/config.json"