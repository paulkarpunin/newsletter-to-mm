import json
import requests
import argparse
import sys
import os

def send_mattermost_message(profile_name, config_path="config.json"):
    # Проверка наличия файла конфигурации
    if not os.path.exists(config_path):
        print(f"Ошибка: Файл конфигурации {config_path} не найден.")
        sys.exit(1)

    # Загрузка конфигурации
    with open(config_path, 'r', encoding='utf-8') as file:
        try:
            config = json.load(file)
        except json.JSONDecodeError:
            print("Ошибка: Неверный формат JSON.")
            sys.exit(1)

    # Проверка наличия профиля
    if profile_name not in config:
        print(f"Ошибка: Профиль '{profile_name}' не найден в конфигурации.")
        sys.exit(1)

    job_data = config[profile_name]
    webhook_url = job_data.get("webhook_url")
    message = job_data.get("message")

    if not webhook_url or not message:
        print("Ошибка: В профиле отсутствуют webhook_url или message.")
        sys.exit(1)

    # Подготовка данных для отправки (аналог Google Apps Script)
    payload = {
        "text": message
    }

    # Отправка запроса
    try:
        response = requests.post(
            webhook_url,
            json=payload, # requests сам установит нужные заголовки и конвертирует dict в JSON
            timeout=10
        )
        response.raise_for_status() # Проверка на HTTP ошибки (4xx, 5xx)
        print(f"Успех. Код ответа: {response.status_code}")
    except requests.exceptions.RequestException as e:
        print(f"Сбой при отправке сообщения: {e}")
        sys.exit(1)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Отправка сообщений в Mattermost через Webhook.")
    parser.add_argument("profile", help="Имя профиля из config.json (например, morning_status)")
    parser.add_argument("--config", default="/opt/mattermost_bot/config.json", help="Путь к файлу конфигурации")
    
    args = parser.parse_args()
    send_mattermost_message(args.profile, args.config)