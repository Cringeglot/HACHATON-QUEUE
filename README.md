# Е-СУО ПочтаТеч — Система электронной очереди Почты России

MVP-решение для оптимизации потоков посетителей в отделениях почтовой связи (ОПС).

---

## Архитектура и стек технологий

* Backend: FastAPI (Python 3.12), SQLAlchemy, Pydantic v2, Uvicorn.
* Database: PostgreSQL (локальное хранение талонов, окон, логов и пользователей).
* Frontend: Flutter Web (Dart), GoRouter (навигация), Динамическое управление сессиями через Secure Storage.
* Контейнеризация: Docker, Docker Compose.

---

## Сценарий 1. Запуск через Docker Compose (Быстрый старт)

Для автоматического развёртывания всей инфраструктуры (бэкенд + база данных PostgreSQL + фронтенд-сервер) в изолированных контейнерах выполните в корневой директории проекта всего одну команду:

```bash
docker compose up --build
```

После успешной сборки и инициализации контейнеров:
*   Основной клиентский фронтенд развернётся по адресу: `http://localhost:3000` (или порту, указанному в вашем nginx/flutter dockerfile).
*   Бэкенд-сервер FastAPI будет доступен по адресу: `http://localhost:8000`
*   Интерактивная документация Swagger API: `http://localhost:8000/docs`

---

## Сценарий 2. Локальное развертывание (Для ручной проверки)

Если раннеры и контейнеры не используются, систему можно пошагово поднять вручную в локальном окружении.

### 1. Подготовка Базы Данных (PostgreSQL)
Убедитесь, что у вас развернута СУБД PostgreSQL и создана целевая база данных.
*   Имя БД: `queue`
*   Шаблон строки подключения (Environment Variable):
    `postgresql+psycopg://YOUR_POSTGRES_USER:YOUR_PASSWORD@localhost:5432/queue`

### 2. Запуск Бэкенда (FastAPI)
Откройте терминал в папке `Backend/` и выполните команды:
```bash
cd Backend
python -m pip install -r requirements.txt
# Установка переменной окружения вашей локальной БД (для Windows PowerShell)
$env:DATABASE_URL="postgresql+psycopg://YOUR_POSTGRES_USER:YOUR_PASSWORD@localhost:5432/queue"
# Запуск сервера
python -m uvicorn app.main:app --reload
```
*Интерактивная документация Swagger API и ручного тестирования СУБД развернется по адресу:* `http://localhost:8000/docs`

### 3. Запуск Фронтенда (Flutter Web)
Откройте второй терминал в папке `frontend/` и выполните команды:
```bash
cd frontend
flutter pub get
```

#### 🔹 Сценарий А. Интерфейс Клиента (Основная сборка)
Запуск экрана выбора ОПС, записи по QR-кодам и получения талонов:
```bash
flutter run -d chrome --web-browser-flag "--disable-web-security"
```

#### 🔹 Сценарий Б. Интерфейс Персонала (Тестовая сборка сотрудников)
Запуск изолированного модуля авторизации сотрудников (Оператор / Руководитель):
```bash
flutter run -t lib/main_test.dart -d chrome --web-browser-flag "--disable-web-security"
```
