#!/bin/bash
# Строгий режим: остановка при любой ошибке
set -e 

# Базовые переменные (замените ветку main на master, если используете старый стандарт)
REPO_RAW_URL="https://raw.githubusercontent.com/paulkarpunin/newsletter-to-mm/main"
INSTALL_DIR="/opt/mattermost_bot"
LOG_DIR="/var/log/mattermost_bot"

echo "==== Инициализация развертывания интеграции Mattermost ===="

# 1. Валидация прав доступа
if [ "$EUID" -ne 0 ]; then
  echo "[ОШИБКА] Скрипт развертывания должен быть запущен с правами root (sudo)."
  exit 1
fi

# 2. Разрешение зависимостей уровня ОС
echo "[1/4] Проверка и установка системных зависимостей..."
apt-get update -qq
apt-get install -y python3 python3-requests > /dev/null

# 3. Подготовка файловой системы
echo "[2/4] Формирование структуры каталогов..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$LOG_DIR"

# 4. Транспорт данных из репозитория
echo "[3/4] Загрузка исполняемого кода..."
curl -sSL "$REPO_RAW_URL/mattermost_sender.py" -o "$INSTALL_DIR/mattermost_sender.py"

# Логика защиты конфигурации: скачиваем шаблон только если боевого конфига еще нет
if [ ! -f "$INSTALL_DIR/config.json" ]; then
    echo "[ИНФО] Боевой config.json не найден. Загрузка шаблона..."
    curl -sSL "$REPO_RAW_URL/config.json.example" -o "$INSTALL_DIR/config.json"
else
    echo "[ИНФО] Обнаружен существующий config.json. Пропуск скачивания шаблона для сохранения ваших настроек."
fi

# 5. Изоляция и безопасность
echo "[4/4] Настройка политик доступа (chmod/chown)..."
# В идеале здесь стоит сменить владельца на непривилегированного пользователя, 
# но для простоты базовой настройки ограничиваем права для всех, кроме текущего владельца
chmod 700 "$INSTALL_DIR"
chmod 700 "$INSTALL_DIR/mattermost_sender.py"
chmod 600 "$INSTALL_DIR/config.json"

echo "==== Развертывание успешно завершено ===="
echo "Дальнейшие действия:"
echo "1. Внесите актуальные вебхуки и тексты сообщений: nano $INSTALL_DIR/config.json"
echo "2. Настройте расписание запуска: crontab -e"