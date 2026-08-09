class VideoItem {
  final String id;
  final String title;
  final String thumbnailUrl;
  final String duration;
  final int views;
  final double rating;
  final String dateAdded;
  final String? previewUrl;
  final List<String> tags;
  final String? channel;

  VideoItem({
    required this.id,
    required this.title,
    required this.thumbnailUrl,
    required this.duration,
    required this.views,
    required this.rating,
    required this.dateAdded,
    this.previewUrl,
    this.tags = const [],
    this.channel,
  });

  factory VideoItem.fromJson(Map<String, dynamic> json) {
    return VideoItem(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? 'Untitled',
      thumbnailUrl: json['thumbnail_url'] ?? json['thumb'] ?? '',
      duration: json['duration'] ?? '0:00',
      views: _parseViews(json['views']),
      rating: _parseRating(json['rating']),
      dateAdded: json['date_added'] ?? '',
      previewUrl: json['preview_url'],
      tags: json['tags'] != null ? List<String>.from(json['tags']) : [],
      channel: json['channel'],
    );
  }

  static int _parseViews(dynamic views) {
    if (views == null) return 0;
    if (views is int) return views;
    if (views is String) {
      final cleaned = views.replaceAll(RegExp(r'[^0-9]'), '');
      return int.tryParse(cleaned) ?? 0;
    }
    return 0;
  }

  static double _parseRating(dynamic rating) {
    if (rating == null) return 0.0;
    if (rating is num) return rating.toDouble();
    if (rating is String) return double.tryParse(rating) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'thumbnail_url': thumbnailUrl,
        'duration': duration,
        'views': views,
        'rating': rating,
        'date_added': dateAdded,
        'preview_url': previewUrl,
        'tags': tags ?? [],  // Safe null handling
        'channel': channel ?? '',  // Safe null handling
      };

  String get formattedViews {
    if (views >= 1000000) {
      return '${(views / 1000000).toStringAsFixed(1)}M';
    } else if (views >= 1000) {
      return '${(views / 1000).toStringAsFixed(1)}K';
    }
    return views.toString();
  }
}

class VideoSource {
  final String videoUrl;
  final String quality;
  final String format;

  VideoSource({
    required this.videoUrl,
    required this.quality,
    required this.format,
  });

  factory VideoSource.fromJson(Map<String, dynamic> json) {
    return VideoSource(
      videoUrl: json['video_url'] ?? json['url'] ?? '',
      quality: json['quality'] ?? '480p',
      format: json['format'] ?? 'mp4',
    );
  }

  /// Serialize to JSON for caching/storage
  Map<String, dynamic> toJson() => {
    'video_url': videoUrl,
    'quality': quality,
    'format': format,
  };

  bool get isHD => quality.contains('720') || quality.contains('1080');
}

class VideoQuality {
  final String label;
  final String url;

  VideoQuality({required this.label, required this.url});

  factory VideoQuality.fromJson(Map<String, dynamic> json) => VideoQuality(
    label: json['label'] ?? json['quality'] ?? 'auto',
    url: json['url'] ?? json['video_url'] ?? '',
  );

  Map<String, dynamic> toJson() => {
    'label': label,
    'url': url,
  };
}

class VideoListResponse {
  final List<VideoItem> videos;
  final int currentPage;
  final int totalPages;
  final bool hasMore;

  VideoListResponse({
    required this.videos,
    required this.currentPage,
    required this.totalPages,
    required this.hasMore,
  });
}
