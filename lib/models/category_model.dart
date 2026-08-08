class Category {
  final String id;
  final String name;
  final String? thumbnailUrl;
  final int videoCount;

  Category({
    required this.id,
    required this.name,
    this.thumbnailUrl,
    this.videoCount = 0,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id']?.toString() ?? json['slug'] ?? '',
      name: json['name'] ?? json['title'] ?? '',
      thumbnailUrl: json['thumbnail_url'] ?? json['thumb'],
      videoCount: json['video_count'] ?? 0,
    );
  }
}

class Tag {
  final String id;
  final String name;
  final int videoCount;

  Tag({
    required this.id,
    required this.name,
    this.videoCount = 0,
  });

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? json['tag'] ?? '',
      videoCount: json['count'] ?? 0,
    );
  }
}

class Channel {
  final String id;
  final String name;
  final String? avatarUrl;
  final int subscriberCount;
  final int videoCount;

  Channel({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.subscriberCount = 0,
    this.videoCount = 0,
  });

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? json['username'] ?? '',
      avatarUrl: json['avatar_url'] ?? json['avatar'],
      subscriberCount: json['subscribers'] ?? 0,
      videoCount: json['videos'] ?? 0,
    );
  }
}
