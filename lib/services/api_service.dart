import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../models/video_model.dart';
import '../models/category_model.dart';
import '../models/search_model.dart';
import '../utils/html_parser.dart';
import '../utils/constants.dart';
import 'cache_manager.dart';

class LeakSexTapeService {
  static final LeakSexTapeService _instance = LeakSexTapeService._internal();
  factory LeakSexTapeService() => _instance;
  LeakSexTapeService._internal();

  final http.Client _client = http.Client();
  final CacheManager _cache = CacheManager();

  Map<String, String> get _headers => {
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9,en-GB;q=0.8',
        'User-Agent': AppConstants.userAgent,
        'Connection': 'keep-alive',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      };

  /// Get latest videos with enhanced error handling
  Future<VideoListResponse> getLatestVideos({int page = 1}) async {
    final cacheKey = 'latest_$page';
    
    try {
      // Check cache first
      final cached = _cache.get(cacheKey);
      if (cached != null && cached is List<VideoItem> && cached.isNotEmpty) {
        return VideoListResponse(
          videos: cached,
          currentPage: page,
          totalPages: page + 1,
          hasMore: true,
        );
      }

      // Build URL - leak-sex-tape.com uses /latest-updates/ endpoint
      final url = page == 1 
          ? '${AppConstants.baseUrl}${AppConstants.latestEndpoint}/'
          : '${AppConstants.baseUrl}${AppConstants.latestEndpoint}/?page=$page';
      
      debugPrint('ApiService: Fetching latest videos from: $url');
      
      final response = await _client.get(Uri.parse(url), headers: _headers).timeout(
            const Duration(seconds: 30),  // Increased timeout
          );

      debugPrint('ApiService: Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        final videos = HtmlParserUtil.parseVideoList(document);
        
        debugPrint('ApiService: Parsed ${videos.length} videos');
        
        if (videos.isNotEmpty) {
          _cache.set(cacheKey, videos, ttl: const Duration(minutes: 10));
        }
        
        return VideoListResponse(
          videos: videos,
          currentPage: page,
          totalPages: page + 1,
          hasMore: videos.isNotEmpty,
        );
      } else if (response.statusCode == 403 || response.statusCode == 503) {
        throw Exception('Доступ ограничен. Попробуйте позже.');
      }
      
      throw Exception('Ошибка загрузки: HTTP ${response.statusCode}');
    } on http.ClientException catch (e) {
      debugPrint('ApiService: Network error: $e');
      throw Exception('Ошибка сети. Проверьте подключение к интернету.');
    } on TimeoutException {
      debugPrint('ApiService: Request timeout');
      throw Exception('Превышено время ожидания. Проверьте соединение.');
    } catch (e) {
      debugPrint('ApiService: Unexpected error: $e');
      throw Exception('Ошибка при загрузке видео: $e');
    }
  }

  /// Search videos with proper encoding
  Future<SearchResult> searchVideos(SearchParams params) async {
    final cacheKey = 'search_${params.query}_${params.page}_${params.sortBy}';
    
    try {
      final cached = _cache.get(cacheKey);
      if (cached != null && cached is List<VideoItem>) {
        return SearchResult(
          videos: cached,
          params: params,
          totalResults: cached.length * params.page,
          currentPage: params.page,
          totalPages: params.page + 1,
        );
      }

      // Build search URL properly encoded
      final queryParams = params.toQueryParams();
      final encodedQueryParams = queryParams.entries.map((e) =>
        '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}'
      ).join('&');
      final url = '${AppConstants.baseUrl}${AppConstants.searchEndpoint}?$encodedQueryParams';
      
      debugPrint('ApiService: Searching: $url');
      
      final response = await _client.get(Uri.parse(url), headers: _headers).timeout(
            const Duration(seconds: 30),
          );

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        final videos = HtmlParserUtil.parseVideoList(document);
        final pagination = HtmlParserUtil.parsePagination(document);
        
        if (videos.isNotEmpty) {
          _cache.set(cacheKey, videos, ttl: const Duration(minutes: 5));
        }
        
        return SearchResult(
          videos: videos,
          params: params,
          totalResults: pagination['total'] ?? videos.length * params.page,
          currentPage: params.page,
          totalPages: pagination['pages'] ?? params.page + 1,
        );
      }
      
      throw Exception('Ошибка поиска: ${response.statusCode}');
    } catch (e) {
      debugPrint('ApiService: Search error: $e');
      rethrow;
    }
  }

  /// Get video source URL with multiple fallbacks
  Future<VideoSource> getVideoSource(String videoId) async {
    final cacheKey = 'source_$videoId';
    
    try {
      // Check cache first
      final cached = _cache.get(cacheKey);
      if (cached != null && cached is VideoSource) {
        return cached;
      }

      // Try to get direct video URL from video page
      final url = '${AppConstants.baseUrl}${AppConstants.videoEndpoint}/$videoId/';
      debugPrint('ApiService: Fetching video source from: $url');
      
      final response = await _client.get(Uri.parse(url), headers: _headers).timeout(
            const Duration(seconds: 30),
          );

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        final source = HtmlParserUtil.parseVideoSource(document, videoId);
        
        if (source != null) {
          debugPrint('ApiService: Got video source: ${source.format} - ${source.quality}');
          _cache.set(cacheKey, source, ttl: const Duration(hours: 1));
          return source;
        }
        
        // Fallback to embed URL
        debugPrint('ApiService: Using embed fallback');
        final embedSource = VideoSource(
          videoUrl: '${AppConstants.baseUrl}/embed/$videoId',
          quality: 'auto',
          format: 'embed',
        );
        _cache.set(cacheKey, embedSource, ttl: const Duration(minutes: 30));
        return embedSource;
      }
      
      // If video page fails, try embed directly
      debugPrint('ApiService: Video page failed (${response.statusCode}), trying embed');
      final embedSource = VideoSource(
        videoUrl: '${AppConstants.baseUrl}/embed/$videoId',
        quality: 'auto',
        format: 'embed',
      );
      return embedSource;
      
    } on TimeoutException {
      debugPrint('ApiService: Video source timeout, using embed fallback');
      return VideoSource(
        videoUrl: '${AppConstants.baseUrl}/embed/$videoId',
        quality: 'auto',
        format: 'embed',
      );
    } catch (e) {
      debugPrint('ApiService: Video source error: $e');
      // Always return embed as last resort
      return VideoSource(
        videoUrl: '${AppConstants.baseUrl}/embed/$videoId',
        quality: 'auto',
        format: 'embed',
      );
    }
  }

  /// Get categories with better parsing
  Future<List<Category>> getCategories() async {
    try {
      final cached = _cache.get('categories');
      if (cached != null && cached is List<Category> && cached.isNotEmpty) {
        return List<Category>.from(cached);
      }

      final url = '${AppConstants.baseUrl}${AppConstants.categoriesEndpoint}/';
      debugPrint('ApiService: Fetching categories from: $url');
      
      final response = await _client.get(Uri.parse(url), headers: _headers).timeout(
            const Duration(seconds: 30),
          );

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        final categories = HtmlParserUtil.parseCategories(document);
        
        debugPrint('ApiService: Parsed ${categories.length} categories');
        
        if (categories.isNotEmpty) {
          _cache.set('categories', categories, ttl: const Duration(hours: 24));
        }
        
        return categories;
      }
      
      throw Exception('Ошибка загрузки категорий: ${response.statusCode}');
    } catch (e) {
      debugPrint('ApiService: Categories error: $e');
      rethrow;
    }
  }

  /// Search tags
  Future<List<Tag>> searchTags(String query) async {
    try {
      final uri = Uri.parse('${AppConstants.baseUrl}${AppConstants.tagsEndpoint}')
          .replace(queryParameters: {'q': query});
      final response = await _client.get(uri, headers: _headers).timeout(
            const Duration(seconds: 15),
          );

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        return HtmlParserUtil.parseTags(document);
      }
      
      return [];
    } catch (e) {
      debugPrint('ApiService: Tags error: $e');
      return [];
    }
  }

  /// Clear all caches
  void clearCache() {
    _cache.clear();
  }

  /// Dispose resources
  void dispose() {
    _client.close();
    _cache.clear();
  }
}

// Helper for timeout exception handling
class TimeoutException implements Exception {
  final String message;
  const TimeoutException([this.message = 'Operation timed out']);
  
  @override
  String toString() => 'TimeoutException: $message';
}
