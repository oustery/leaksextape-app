import 'package:flutter/foundation.dart';
import '../models/video_model.dart';
import '../models/search_model.dart';
import '../models/category_model.dart' as app_models;
import '../services/api_service.dart';

class VideoProvider with ChangeNotifier {
  final LeakSexTapeService _api = LeakSexTapeService();

  // State
  List<VideoItem> _videos = [];
  List<VideoItem> _searchResults = [];
  List<app_models.Category> _categories = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;
  int _currentPage = 1;
  bool _hasMorePages = true;

  // Search state
  SearchParams? _currentSearchParams;
  int _totalSearchResults = 0;

  // Getters
  List<VideoItem get videos => _videos;
  List<VideoItem> get searchResults => _searchResults;
  List<app_models.Category> get categories => _categories;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get errorMessage => _errorMessage;
  bool get hasMorePages => _hasMorePages;
  int get currentPage => _currentPage;
  SearchParams? get currentSearchParams => _currentSearchParams;
  int get totalSearchResults => _totalSearchResults;

  bool get hasVideos => _videos.isNotEmpty;
  bool get hasSearchResults => _searchResults.isNotEmpty;
  bool get hasError => _errorMessage != null;

  // Load latest videos
  Future<void> loadLatestVideos({bool refresh = false}) async {
    if (_isLoading) return;
    
    if (refresh) {
      _currentPage = 1;
      _hasMorePages = true;
    } else if (_videos.isNotEmpty && !refresh) {
      return;
    }

    _setLoading(true);
    _clearError();

    try {
      final response = await _api.getLatestVideos(page: _currentPage);
      
      if (refresh || _currentPage == 1) {
        _videos = response.videos;
      } else {
        _videos = [..._videos, ...response.videos];
      }
      
      _hasMorePages = response.hasMore;
      _currentPage++;
      
      notifyListeners();
    } catch (e) {
      _setError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      _setLoading(false);
    }
  }

  // Load more videos (pagination)
  Future<void> loadMoreVideos() async {
    if (_isLoadingMore || !_hasMorePages) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final response = await _api.getLatestVideos(page: _currentPage);
      _videos = [..._videos, ...response.videos];
      _hasMorePages = response.hasMore;
      _currentPage++;
      
      notifyListeners();
    } catch (e) {
      debugPrint('Load more error: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  // Search videos
  Future<void> searchVideos(SearchParams params) async {
    _setLoading(true);
    _clearError();
    _currentSearchParams = params;

    try {
      final result = await _api.searchVideos(params);
      _searchResults = result.videos;
      _totalSearchResults = result.totalResults;
      
      notifyListeners();
    } catch (e) {
      _setError(e.toString().replaceFirst('Exception: ', ''));
      _searchResults = [];
    } finally {
      _setLoading(false);
    }
  }

  // Load more search results
  Future<void> loadMoreSearchResults() async {
    if (_isLoadingMore || _currentSearchParams == null || !_hasMorePages) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final newParams = _currentSearchParams!.copyWith(page: _currentSearchParams!.page + 1);
      final result = await _api.searchVideos(newParams);
      _searchResults = [..._searchResults, ...result.videos];
      _currentSearchParams = newParams;
      
      notifyListeners();
    } catch (e) {
      debugPrint('Load more search error: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  // Clear search results
  void clearSearch() {
    _searchResults = [];
    _currentSearchParams = null;
    _totalSearchResults = 0;
    notifyListeners();
  }

  // Load categories
  Future<void> loadCategories() async {
    if (_categories.isNotEmpty) return;

    try {
      _categories = await _api.getCategories();
      notifyListeners();
    } catch (e) {
      debugPrint('Load categories error: $e');
    }
  }

  // Refresh data
  Future<void> refresh() async {
    await loadLatestVideos(refresh: true);
  }

  // Internal methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }
}
