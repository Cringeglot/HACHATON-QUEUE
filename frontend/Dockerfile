# Используем официальный (или популярный комьюнити) образ с Flutter
FROM ghcr.io/cirruslabs/flutter:3.19.0

# Рабочая директория внутри контейнера
WORKDIR /app

# Копируем файлы конфигурации для установки зависимостей
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Копируем весь остальной код
COPY . .

# Открываем порт для веб-сервера
EXPOSE 8080

# Запускаем Flutter в режиме веб-сервера на всех интерфейсах (0.0.0.0)
CMD ["flutter", "run", "-d", "web-server", "--web-hostname", "0.0.0.0", "--web-port", "8080"]