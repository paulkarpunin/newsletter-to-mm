import json
import os
import re
import shutil
import sys

CONFIG_PATH = "/opt/mattermost_bot/config.json"
CRON_PATH = "/etc/cron.d/mattermost_bot"
CMD_BASE = "root /usr/bin/python3 /opt/mattermost_bot/mattermost_sender.py"
LOG_BASE = ">> /var/log/mattermost_bot/execution.log 2>&1"

def safe_input(prompt):
    """Обеспечивает ввод без падений из-за кодировок терминала."""
    sys.stdout.write(prompt)
    sys.stdout.flush()
    # Читаем сырые байты из stdin
    line = sys.stdin.buffer.readline()
    try:
        # Пытаемся декодировать как UTF-8
        return line.decode('utf-8').strip()
    except UnicodeDecodeError:
        # Если не вышло (например, ввод в CP1251) — декодируем как кириллицу Windows
        return line.decode('cp1251', errors='replace').strip()

def load_config():
    if not os.path.exists(CONFIG_PATH):
        return {}
    try:
        with open(CONFIG_PATH, 'r', encoding='utf-8') as file:
            return json.load(file)
    except Exception:
        print("\n[КРИТИЧЕСКАЯ ОШИБКА] Не удалось прочитать config.json. Попробуйте сбросить его: echo '{}' | sudo tee " + CONFIG_PATH)
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
    os.system("systemctl restart cron")

def update_cron_entry(profile_name, time_str, days_str):
    try:
        hour, minute = time_str.split(':')
        hour, minute = int(hour), int(minute)
    except ValueError:
        print("Ошибка: Неверный формат времени.")
        return False

    lines = read_cron()
    lines = [line for line in lines if f" {profile_name} " not in line]
    if lines and not lines[-1].endswith('\n'):
        lines[-1] += '\n'
        
    new_entry = f"{minute:02d} {hour:02d} * * {days_str} {CMD_BASE} {profile_name} --config {CONFIG_PATH} {LOG_BASE}\n"
    lines.append(new_entry)
    write_cron(lines)
    return True

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
        print(f"[{name}] | Расписание: {schedule} | URL: {data.get('webhook_url')[:30]}...")
    print("-------------------------")

def add_or_edit_profile(config):
    print("\n--- Создание / Редактирование ---")
    profile_name = safe_input("Имя профиля (лат.): ")
    if not profile_name or not re.match(r"^[a-zA-Z0-9_]+$", profile_name):
        print("Ошибка: Только латиница и цифры.")
        return

    webhook_url = safe_input("URL Webhook'а: ")
    message = safe_input("Текст сообщения: ")
    time_str = safe_input("Время запуска (ЧЧ:ММ): ")
    days_str = safe_input("Дни недели (напр. 1-5): ")

    if not all([webhook_url, message, time_str, days_str]):
        print("Ошибка: Все поля обязательны.")
        return

    if update_cron_entry(profile_name, time_str, days_str):
        config[profile_name] = {"webhook_url": webhook_url, "message": message}
        save_config(config)
        print(f"[УСПЕХ] Профиль '{profile_name}' сохранен.")

def uninstall_system():
    print("\n[DANGER] Полное удаление системы!")
    confirm = safe_input("Введите 'DELETE' для подтверждения: ")
    if confirm != 'DELETE': return

    if os.path.exists(CRON_PATH): os.remove(CRON_PATH)
    os.system("systemctl restart cron")
    for d in ["/var/log/mattermost_bot", "/opt/mattermost_bot"]:
        if os.path.exists(d): shutil.rmtree(d)
    if os.path.exists("/usr/local/bin/gomattermost"): os.remove("/usr/local/bin/gomattermost")
    print("Система удалена.")
    exit(0)

def main_menu():
    if os.geteuid() != 0:
        print("Запустите через sudo или gomattermost.")
        exit(1)
    while True:
        config = load_config()
        print("\n=== Панель управления Mattermost Bot ===")
        print("1. Показать все рассылки")
        print("2. Добавить или изменить рассылку")
        print("3. Удалить рассылку")
        print("4. Удалить скрипт с сервера")
        print("0. Выход")
        choice = safe_input("Действие (0-4): ")
        if choice == '1': list_profiles(config)
        elif choice == '2': add_or_edit_profile(config)
        elif choice == '3':
            name = safe_input("Имя профиля: ")
            if name in config:
                del config[name]
                save_config(config)
                lines = [l for l in read_cron() if f" {name} " not in l]
                write_cron(lines)
                print("Удалено.")
        elif choice == '4': uninstall_system()
        elif choice == '0': break

if __name__ == "__main__":
    main_menu()