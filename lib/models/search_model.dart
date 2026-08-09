import '../models/video_model.dart';

class SearchParams {
  final String query;
  final String sortBy;
  final String category;
  final String? duration;
  final String? quality;
  final int page;

  SearchParams({
    required this.query,
    this.sortBy = 'relevance',
    this.category = 'all',
    this.duration,
    this.quality,
    this.page = 1,
  });

  SearchParams copyWith({
    String? query,
    String? sortBy,
    String? category,
    String? duration,
    String? quality,
    int? page,
  }) {
    return SearchParams(
      query: query ?? this.query,
      sortBy: sortBy ?? this.sortBy,
      category: category ?? this.category,
      duration: duration ?? this.duration,
      quality: quality ?? this.quality,
      page: page ?? this.page,
    );
  }

  Map<String, String> toQueryParams() {
    final params = <String, String>{
      'q': query,  // Fixed: site uses 'q' not 'k'
      'sort': sortBy,
      'page': page.toString(),
    };
    if (category != 'all') params['category_id'] = category;
    if (duration != null) params['duration'] = duration!;
    if (quality != null) params['quality'] = quality!;
    return params;
  }
}

class SearchResult {
  final List<VideoItem> videos;
  final SearchParams params;
  final int totalResults;
  final int currentPage;
  final int totalPages;

  SearchResult({
    required this.videos,
    required this.params,
    required this.totalResults,
    required this.currentPage,
    required this.totalPages,
  });
}

class SearchHistoryItem {
  final String id;
  final String query;
  final DateTime searchedAt;

  SearchHistoryItem({
    required this.id,
    required this.query,
    required this.searchedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'query': query,
        'searched_at': searchedAt.toIso8601String(),
      };
}

class TrendingSearch {
  final String query;
  final int count;

  TrendingSearch({required this.query, required this.count});
}
