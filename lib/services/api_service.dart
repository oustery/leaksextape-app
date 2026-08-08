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
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
        'User-Agent': AppConstants.userAgent,
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1',
      };

  Future<VideoListResponse> getLatestVideos({int page = 1}) async {
    final cacheKey = 'latest_$page';
    
    try {
      final cached = _cache.get(cacheKey);
      if (cached != null) {
        return VideoListResponse(
          videos: cached,
          currentPage: page,
          totalPages: page + 1,
          hasMore: true,
        );
      }

      final url = '${AppConstants.baseUrl}${AppConstants.latestEndpoint}?page=$page';
      final response = await _client.get(Uri.parse(url), headers: _headers).timeout(
            const Duration(seconds: 15),
          );

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        final videos = HtmlParserUtil.parseVideoList(document);
        
        _cache.set(cacheKey, videos, ttl: const Duration(minutes: 10));
        
        return VideoListResponse(
          videos: videos,
          currentPage: page,
          totalPages: page + 1,
          hasMore: videos.isNotEmpty,
        );
      }
      
      throw Exception('Failed to load videos: ${response.statusCode}');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<SearchResult> searchVideos(SearchParams params) async {
    final cacheKey = 'search_${params.query}_${params.page}_${params.sortBy}';
    
    try {
      final queryParams = params.toQueryParams();
      final queryString = queryParams.entries.map((e) => '${e.key}=${e.value}').join('&');
      final url = '${AppConstants.baseUrl}${AppConstants.searchEndpoint}?$queryString';
      
      final response = await _client.get(Uri.parse(url), headers: _headers).timeout(
            const Duration(seconds: 15),
          );

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        final videos = HtmlParserUtil.parseVideoList(document);
        final pagination = HtmlParserUtil.parsePagination(document);
        
        return SearchResult(
          videos: videos,
          params: params,
          totalResults: pagination['total'] ?? videos.length * params.page,
          currentPage: params.page,
          totalPages: pagination['pages'] ?? params.page + 1,
        );
      }
      
      throw Exception('Search failed: ${response.statusCode}');
    } catch (e) {
      throw Exception('Search error: $e');
    }
  }

  Future<VideoSource> getVideoSource(String videoId) async {
    final cacheKey = 'source_$videoId';
    
    try {
      final cached = _cache.get(cacheKey);
      if (cached != null && cached is VideoSource) {
        return cached;
      }

      final url = '${AppConstants.baseUrl}${AppConstants.videoEndpoint}/$videoId';
      final response = await _client.get(Uri.parse(url), headers: _headers).timeout(
            const Duration(seconds: 15),
          );

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        final source = HtmlParserUtil.parseVideoSource(document, videoId);
        
        if (source != null) {
          _cache.set(cacheKey, source, ttl: const Duration(hours: 1));
          return source;
        }
        
        throw Exception('Could not extract video source');
      }
      
      throw Exception('Failed to load video: ${response.statusCode}');
    } catch (e) {
      throw Exception('Video loading error: $e');
    }
  }

  Future<List<Category>> getCategories() async {
    try {
      final cached = _cache.get('categories');
      if (cached != null) {
        return List<Category>.from(cached as List);
      }

      final url = '${AppConstants.baseUrl}${AppConstants.categoriesEndpoint}';
      final response = await _client.get(Uri.parse(url), headers: _headers).timeout(
            const Duration(seconds: 15),
          );

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        final categories = HtmlParserUtil.parseCategories(document);
        
        _cache.set('categories', categories, ttl: const Duration(hours: 24));
        
        return categories;
      }
      
      throw Exception('Failed to load categories: ${response.statusCode}');
    } catch (e) {
      throw Exception('Categories error: $e');
    }
  }

  Future<List<Tag>> searchTags(String query) async {
    try {
      final url = '${AppConstants.baseUrl}${AppConstants.tagsEndpoint}?q=$query';
      final response = await _client.get(Uri.parse(url), headers: _headers).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        return HtmlParserUtil.parseTags(document);
      }
      
      return [];
    } catch (e) {
      return [];
    }
  }

  void dispose() {
    _client.close();
    _cache.clear();
  }
}
