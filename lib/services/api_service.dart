import 'package:flutter/foundation.dart' show debugPrint;
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

  /// Get video source URL with multiple fallbacks - FIXED: prioritize direct URLs
  Future<VideoSource> getVideoSource(String videoId) async {
    final cacheKey = 'source_$videoId';
    
    try {
      // Check cache first
      final cached = _cache.get(cacheKey);
      if (cached != null && cached is VideoSource) {
        // Don't return cached embed URLs - they don't work
        if (cached.format != 'embed') {
          return cached;
        }
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
          
          // Only cache if it's a direct URL (not embed - embed doesn't work!)
          if (source.format != 'embed') {
            _cache.set(cacheKey, source, ttl: const Duration(hours: 1));
          }
          
          return source;
        }
        
        // Try to extract direct URL manually from response body
        debugPrint('ApiService: Parser failed, trying manual extraction');
        final manualUrl = _extractDirectVideoUrl(response.body, videoId);
        if (manualUrl != null) {
          final directSource = VideoSource(
            videoUrl: manualUrl,
            quality: 'auto',
            format: 'mp4',
          );
          _cache.set(cacheKey, directSource, ttl: const Duration(hours: 1));
          return directSource;
        }
      }
      
      // Last resort: try to construct get_file URL pattern
      debugPrint('ApiService: Trying get_file URL pattern');
      final getFileUrl = await _tryGetFileUrl(videoId);
      if (getFileUrl != null) {
        final fileSource = VideoSource(
          videoUrl: getFileUrl,
          quality: 'auto',
          format: 'mp4',
        );
        _cache.set(cacheKey, fileSource, ttl: const Duration(minutes: 30));
        return fileSource;
      }
      
      // Absolute last resort - embed (likely won't work but try anyway)
      debugPrint('ApiService: Using embed as absolute last resort');
      return VideoSource(
        videoUrl: '${AppConstants.baseUrl}/embed/$videoId',
        quality: 'auto',
        format: 'embed',
      );
      
    } on TimeoutException {
      debugPrint('ApiService: Video source timeout');
      // Return error that will be handled by UI
      throw Exception('Превышено время ожидания загрузки видео');
    } catch (e) {
      debugPrint('ApiService: Video source error: $e');
      rethrow;  // Let the caller handle the error properly
    }
  }
  
  /// Extract direct video URL from HTML response body
  String? _extractDirectVideoUrl(String htmlBody, String videoId) {
    try {
      // Look for video_url in flashvars - use simple pattern to avoid quote escaping issues
      final urlPattern = RegExp(r'video_url\s*:\s*["\x27]([^"\x27]+)["\x27]', caseSensitive: false);
      final match = urlPattern.firstMatch(htmlBody);
      if (match != null) {
        var url = match.group(1)?.trim() ?? '';
        if (url.isNotEmpty && url.startsWith('http')) {
          debugPrint('ApiService: Extracted direct URL from flashvars');
          return url;
        }
      }
      
      // Look for get_file URLs
      final getFilePattern = RegExp(r'(https?://[^\s"\x27]*get_file[^\s"\x27]*\.mp4[^\s"\x27]*)', caseSensitive: false);
      final fileMatch = getFilePattern.firstMatch(htmlBody);
      if (fileMatch != null) {
        var url = fileMatch.group(1)?.trim() ?? '';
        if (url.isNotEmpty) {
          debugPrint('ApiService: Extracted get_file URL');
          return url;
        }
      }
    } catch (e) {
      debugPrint('ApiService: Error extracting direct URL: $e');
    }
    return null;
  }
  
  /// Try to construct get_file URL by fetching video page and finding token
  Future<String?> _tryGetFileUrl(String videoId) async {
    try {
      // The site uses pattern: /get_file/{x}/{token}/{category}/{videoId}/{videoId}.mp4/?v-acctoken={token}
      // We need to extract this from the page
      final url = '${AppConstants.baseUrl}/video/$videoId/';
      final response = await _client.get(Uri.parse(url), headers: _headers).timeout(
        const Duration(seconds: 15),
      );
      
      if (response.statusCode == 200) {
        return _extractDirectVideoUrl(response.body, videoId);
      }
    } catch (e) {
      debugPrint('ApiService: Error getting file URL: $e');
    }
    return null;
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
