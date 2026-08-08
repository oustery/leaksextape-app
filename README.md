# LeakSexTape Flutter App

## 📱 Описание

Flutter приложение для просмотра видео с leak-sex-tape.com с полноценным функционалом:
- Поиск и просмотр видео
- Избранное (локальная база данных)
- История просмотров
- Категории
- Темная/светлая тема
- Адаптивный UI

## 🛠 Технологии

- **Framework**: Flutter 3.44.7 (Dart 3.12)
- **State Management**: Provider
- **Video Player**: Chewie + video_player
- **Local DB**: SQLite (sqflite)
- **HTTP**: http package + HTML парсинг
- **Caching**: CachedNetworkImage + CacheManager

## 📁 Структура проекта

```
lib/
├── main.dart                          # Точка входа, MaterialApp
├── models/
│   ├── video_model.dart               # VideoItem, VideoSource, VideoQuality
│   ├── category_model.dart            # Category, Channel
│   ├── tag_model.dart                 # Tag
│   └── search_model.dart              # SearchParams, SearchResult
├── services/
│   ├── api_service.dart               # LeakSexTapeService (HTML парсинг)
│   └── database_service.dart          # SQLite (избранное, история)
├── screens/
│   ├── home_screen.dart               # Главная страница (сетка видео)
│   ├── search_screen.dart             # Поиск с историей
│   ├── video_player_screen.dart       # Плеер + связанные видео
│   ├── categories_screen.dart         # Бrowsing категорий
│   └── favorites_screen.dart          # Избранное
├── widgets/
│   ├── video_card_widget.dart         # Карточка видео (grid/list)
│   └── shimmer_loading.dart           # Shimmer эффекты загрузки
├── providers/
│   └── video_provider.dart            # State management
└── utils/
    ├── constants.dart                 # Константы API
    ├── html_parser.dart               # Парсер HTML страниц
    └── cache_manager.dart             # Кэширование ответов
```

## 🚀 Сборка проекта

### Требования
- Flutter SDK >= 3.0.0
- Android SDK (API 21+)
- Java 17+
- Gradle 8.7+

### Инструкция по сборке

```bash
# 1. Клонировать проект
cd /path/to/leaksextape_app

# 2. Установить зависимости
flutter pub get

# 3. (Опционально) Проверить код
flutter analyze

# 4. Debug APK
flutter build apk --debug

# 5. Release APK (оптимизированный)
flutter build apk --release --shrink --obfuscate

# APK будет в: build/app/outputs/flutter-apk/
```

### Быстрая сборка через скрипт
```bash
chmod +x build.sh
./build.sh debug    # Debug версия
./build.sh release  # Release версия
```

## 🔧 Конфигурация

### Android (android/app/build.gradle)
- `minSdk`: 21
- `targetSdk`: 34
- `applicationId`: com.example.leaksextape_app
- ProGuard включен для release сборки

### Оптимизации release сборки
- `minifyEnabled = true` - обфускация кода
- `shrinkResources = true` - удаление неиспользуемых ресурсов
- ProGuard правила для Flutter плагинов

## 📡 API Интеграция

### Методы LeakSexTapeService
- `searchVideos(params)` - поиск видео
- `getLatestVideos(page)` - последние видео
- `getVideoSource(id)` - URL потока видео
- `getCategories()` - список категорий
- `searchTags(query)` - поиск тегов

### HTML Парсинг
Сайт не имеет REST API, поэтому используется:
1. Загрузка HTML страницы
2. Извлечение данных через CSS селекторы
3. Парсинг JavaScript flashvars для URL видео
4. Извлечение токена доступа (`v-acctoken`)

## 💾 Локальное хранение

### Таблицы SQLite
- `favorites` - избранные видео
- `history` - история просмотров с прогрессом
- `search_history` - история поиска

## ⚠️ Важные замечания

1. **Cloudflare Protection** - сайт защищен Cloudflare WAF, что может блокировать автоматические запросы
2. **Token-based Access** - видео URL содержат временные токены
3. **Adult Content** - приложение не будет допущено в Google Play / App Store
4. **HTML Parsing** - при изменении структуры сайта потребуется обновление парсера

## 🔐 Безопасность

- Все сетевые запросы через HTTPS
- User-Agent маскируется под мобильный браузер
- Токены доступа не сохраняются локально
- Локальные данные хранятся в зашифрованном хранилище (Android Keystore)

## 📝 Лицензия

Только для образовательных целей.
