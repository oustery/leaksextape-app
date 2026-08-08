class AppConstants {
  // App Info
  static const String appName = 'LeakSexTape';
  static const String appVersion = '1.0.0';

  // API Configuration
  static const String baseUrl = 'https://leak-sex-tape.com';
  
  // Endpoints
  static const String latestEndpoint = '/latest-updates';
  static const String trendingEndpoint = '/trending';
  static const String searchEndpoint = '/search';
  static const String videoEndpoint = '/video';
  static const String categoriesEndpoint = '/categories';
  static const String tagsEndpoint = '/tags';
  static const String channelsEndpoint = '/channels';

  // HTTP Headers - Mobile User Agent for better compatibility
  static const String userAgent =
      'Mozilla/5.0 (Linux; Android 14; Pixel 7) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/120.0.0.0 Mobile Safari/537.36';

  // Cache Durations
  static const int cacheMaxSize = 100;
  static const Duration videoListCacheDuration = Duration(minutes: 10);
  static const Duration categoryCacheDuration = Duration(hours: 24);
  static const Duration videoSourceCacheDuration = Duration(hours: 1);

  // Database Configuration
  static const String databaseName = 'leaksextape.db';
  static const int databaseVersion = 2;

  // UI Constants
  static const int videosPerPage = 20;
  static const int maxSearchHistory = 10;
  static const int maxFavoritesDisplay = 50;

  // Pagination
  static const int initialPage = 1;

  // Error Messages
  static const String networkErrorMessage = 'Проверьте подключение к интернету';
  static const String generalErrorMessage = 'Произошла ошибка. Попробуйте позже';
  static const String noVideosMessage = 'Видео не найдены';
  static const String noFavoritesMessage = 'Избранное пусто';
}
