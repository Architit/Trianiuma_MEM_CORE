Autopilot — локальный автопилот для Windows (prototype)

Файлы: installer.ps1, service/ (скрипты), requirements.txt, config.example.yaml, .env.template

Запуск инсталлятора:
1) Скопируй в B:\CORE\autopilot_setup
2) Запусти PowerShell от имени администратора: .\installer.ps1

После установки: сменить AUTOPILOT_TOKEN и ADMIN_PIN через /admin/change_credentials.
Для критичных admin-действий требуется `admin_mfa_code`.
Для всех API-запросов требуется `key_version`, совпадающий с `ACTIVE_KEY_VERSION`.
