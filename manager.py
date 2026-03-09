import json
import os
import re

CONFIG_PATH = "/opt/mattermost_bot/config.json"
CRON_PATH = "/etc/cron.d/mattermost_bot"
CMD_BASE = "root /usr/bin/python3 /opt/mattermost_bot/mattermost_sender.py"
LOG_BASE = ">> /var/log/mattermost_bot/execution.log 2>&1"

def load_config():
    if not os.path.exists(CONFIG_PATH):
        return {}
    try:
        with open(CONFIG_PATH, 'r', encoding='utf-8') as file:
            return json.load(file)
    except json.JSONDecodeError:
        print("\n[КРИТИЧЕСКАЯ ОШИБКА] Файл config.json поврежден.")
        exit(1)

def save_config(config):
    with open(CONFIG_PATH, 'w', encoding='utf-8') as file:
        json.dump(config, file, indent=4, ensure_ascii=False)

def read_cron():
    if not os.path.exists(CRON_PATH):
        return []
    with open(CRON_PATH, 'r', encoding='utf-8') as f:
        return f.readlines()

def write_cron(lines):
    with open(CRON_PATH, 'w', encoding='utf-8') as f:
        f.writelines(lines)
    os.chmod(CRON_PATH, 0o644)
    # Перезагрузка демона cron для немедленного применения
    os.system("systemctl reload cron")

def update_cron_entry(profile_name, time_str, days_str):
    try:
        hour, minute = time_str.split(':')
        hour, minute = int(hour), int(minute)
    except ValueError:
        print("Ошибка: Неверный формат времени. Используйте ЧЧ:ММ.")
        return False

    lines = read_cron()
    # Удаляем старые записи этого профиля
    lines = [line for line in lines if f" {profile_name} " not in line]
    
    if lines and not lines[-1].endswith('\n'):
        lines[-1] += '\n'
        
    new_entry = f"{minute:02d} {hour:02d} * * {days_str} {CMD_BASE} {profile_name} --config {CONFIG_PATH} {LOG_BASE}\n"
    lines.append(new_entry)
    write_cron(lines)
    return True

def delete_cron_entry(profile_name):
    lines = read_cron()
    lines = [line for line in lines if f" {profile_name} " not in line]
    write_cron(lines)

def list_profiles(config):
    print("\n--- Активные рассылки ---")
    if not config:
        print("Профили не найдены.")
        return
        
    cron_lines = read_cron()
    for name, data in config.items():
        schedule = "Не задано в cron"
        for line in cron_lines:
            if f" {name} " in line and not line.startswith('#'):
                parts = line.split()
                schedule = f"Время: {parts[1]}:{parts[0]}, Дни: {parts[4]}"
                break
                
        print(f"[{name}]")
        print(f"  Расписание: {schedule}")
        print(f"  URL: {data.get('webhook_url')}")
        print(f"  MSG: {data.get('message')}")
    print("-------------------------")

def add_or_edit_profile(config):
    print("\n--- Создание / Редактирование ---")
    profile_name = input("Имя профиля (лат., без пробелов, напр. dev_team): ").strip()
    if not profile_name or not re.match(r"^[a-zA-Z0-9_]+$", profile_name):
        print("Ошибка: Недопустимое имя профиля.")
        return

    webhook_url = input("URL Webhook'а: ").strip()
    message = input("Текст сообщения: ").strip()
    time_str = input("Время запуска (ЧЧ:ММ, напр. 09:15): ").strip()
    days_str = input("Дни недели (1-5 будни, * каждый день, 1,3,5 выборочно): ").strip()

    if not all([webhook_url, message, time_str, days_str]):
        print("Ошибка: Все поля обязательны к заполнению.")
        return

    if update_cron_entry(profile_name, time_str, days_str):
        config[profile_name] = {"webhook_url": webhook_url, "message": message}
        save_config(config)
        print(f"\n[УСПЕХ] Профиль '{profile_name}' сохранен и добавлен в расписание.")

def delete_profile(config):
    print("\n--- Удаление ---")
    profile_name = input("Имя профиля для удаления: ").strip()
    
    if profile_name in config:
        del config[profile_name]
        save_config(config)
        delete_cron_entry(profile_name)
        print(f"[УСПЕХ] Профиль '{profile_name}' удален из конфигурации и расписания.")
    else:
        print("Ошибка: Профиль не найден.")

def main_menu():
    # Проверка прав root
    if os.geteuid() != 0:
        print("[ОШИБКА] Менеджер должен запускаться с правами root (sudo).")
        exit(1)

    while True:
        config = load_config()
        print("\n=== Панель управления Mattermost Bot ===")
        print("1. Показать все рассылки")
        print("2. Добавить или изменить рассылку")
        print("3. Удалить рассылку")
        print("0. Выход")
        
        choice = input("Действие (0-3): ").strip()
        if choice == '1': list_profiles(config)
        elif choice == '2': add_or_edit_profile(config)
        elif choice == '3': delete_profile(config)
        elif choice == '0': break
        else: print("Неверный ввод.")

if __name__ == "__main__":
    main_menu()