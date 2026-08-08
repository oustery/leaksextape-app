import 'package:html/dom.dart' as dom;
import '../models/video_model.dart';
import '../models/category_model.dart';

class HtmlParserUtil {
  static List<VideoItem> parseVideoList(dom.Document document) {
    final videos = <VideoItem>[];
    
    try {
      // Try multiple selectors for video items
      final videoElements = document.querySelectorAll(
        '.video-item, .thumb-item, .video-block, [class*="video"], .thumb'
      );

      for (final element in videoElements) {
        try {
          final video = _parseVideoElement(element);
          if (video != null && video.id.isNotEmpty) {
            videos.add(video);
          }
        } catch (_) {
          continue;
        }
      }

      // Fallback: look for links with video patterns
      if (videos.isEmpty) {
        final links = document.querySelectorAll('a[href*="/video/"], a[href*="/v/"]');
        for (final link in links) {
          try {
            final video = _parseVideoFromLink(link);
            if (video != null && !videos.any((v) => v.id == video.id)) {
              videos.add(video);
            }
          } catch (_) {
            continue;
          }
        }
      }
    } catch (e) {
      debugPrint('Error parsing video list: $e');
    }
    
    return videos;
  }

  static VideoItem? _parseVideoElement(dom.Element element) {
    // Extract ID from href or data attribute
    String? id;
    final anchor = element.querySelector('a') ?? (element.localName == 'a' ? element : null);
    
    if (anchor != null) {
      final href = anchor.attributes['href'] ?? '';
      final idMatch = RegExp(r'/(?:video|v)/(\d+)').firstMatch(href);
      if (idMatch != null) {
        id = idMatch.group(1);
      } else {
        id = href.split('/').last.replaceAll(RegExp(r'\.html?$'), '');
      }
    } else {
      id = element.attributes['data-id'];
    }

    // Extract title
    String title = '';
    final titleEl = element.querySelector('.title, .video-title, h2, h3, [class*="title"]');
    if (titleEl != null) {
      title = titleEl.text.trim();
    } else if (anchor != null) {
      title = anchor.attributes['title'] ?? anchor.attributes['alt'] ?? '';
    }

    // Extract thumbnail
    String thumbnailUrl = '';
    final img = element.querySelector('img');
    if (img != null) {
      thumbnailUrl = img.attributes['data-src'] ?? 
                    img.attributes['data-thumb'] ?? 
                    img.attributes['src'] ?? '';
    }

    // Extract duration
    String duration = '';
    final durationEl = element.querySelector('.duration, .length, [class*="duration"], [class*="time"]');
    if (durationEl != null) {
      duration = durationEl.text.trim();
    }

    // Extract views
    int views = 0;
    final viewsEl = element.querySelector('.views, [class*="views"], [class*="hits"]');
    if (viewsEl != null) {
      final viewsText = viewsEl.text.replaceAll(RegExp(r'[^0-9]'), '');
      views = int.tryParse(viewsText) ?? 0;
    }

    // Extract rating
    double rating = 0.0;
    final ratingEl = element.querySelector('.rating, .stars, [class*="rating"], [class*="percent"]');
    if (ratingEl != null) {
      final ratingText = ratingText = ratingEl.text.replaceAll('%', '').trim();
      rating = double.tryParse(ratingText) ?? 0.0;
    }

    if (id == null || id.isEmpty || title.isEmpty) return null;

    return VideoItem(
      id: id,
      title: title,
      thumbnailUrl: thumbnailUrl,
      duration: duration,
      views: views,
      rating: rating,
      dateAdded: DateTime.now().toIso8601String(),
    );
  }

  static VideoItem? _parseVideoFromLink(dom.Element link) {
    final href = link.attributes['href'] ?? '';
    if (href.isEmpty) return null;

    final idMatch = RegExp(r'/(?:video|v)/(\d+)').firstMatch(href);
    final id = idMatch?.group(1) ?? href.split('/').last;
    
    final title = link.attributes['title'] ?? 
                  link.text.trim().substring(0, link.text.trim().length.clamp(0, 100));
    
    if (id.isEmpty || title.isEmpty) return null;

    return VideoItem(
      id: id,
      title: title,
      thumbnailUrl: '',
      duration: '',
      views: 0,
      rating: 0,
      dateAdded: '',
    );
  }

  static VideoSource? parseVideoSource(dom.Document document, String videoId) {
    try {
      // Method 1: Look for flashvars or video player config
      final scripts = document.querySelectorAll('script');
      
      for (final script in scripts) {
        final content = script.text;
        
        // Look for flashvars pattern
        if (content.contains('flashvars') || content.contains('video_url') || content.contains('source')) {
          // Try to extract video URL
          final urlPatterns = [
            RegExp(r"video_url['\":\s]+['\"]([^'\"]+)['\"]"),
            RegExp(r"source['\":\s]+['\"]([^'\"]+\.mp4[^'\"]*)['\"]"),
            RegExp(r"file['\":\s]+['\"]([^'\"]+)['\"]"),
            RegExp(r"v-acctoken=([^&\"\s']+)", caseSensitive: false),
            RegExp(r"'([^']*\.mp4[^']*)'", caseSensitive: false),
          ];

          for (final pattern in urlPatterns) {
            final match = pattern.firstMatch(content);
            if (match != null) {
              var videoUrl = match.group(1) ?? '';
              
              // Handle relative URLs
              if (videoUrl.startsWith('//')) {
                videoUrl = 'https:$videoUrl';
              } else if (videoUrl.startsWith('/') && !videoUrl.startsWith('//')) {
                videoUrl = 'https://leak-sex-tape.com$videoUrl';
              }

              if (videoUrl.isNotEmpty) {
                return VideoSource(
                  videoUrl: videoUrl,
                  quality: _detectQuality(content),
                  format: 'mp4',
                );
              }
            }
          }
        }
      }

      // Method 2: Look for iframe embed sources
      final iframe = document.querySelector('iframe[src*="player"], iframe[src*="embed"], iframe[src*="video"]');
      if (iframe != null) {
        final src = iframe.attributes['src'] ?? '';
        if (src.isNotEmpty) {
          return VideoSource(
            videoUrl: src,
            quality: 'auto',
            format: 'embed',
          );
        }
      }

      // Method 3: Look for direct video elements
      final videoEl = document.querySelector('video source[src], video[src]');
      if (videoEl != null) {
        final src = videoEl.attributes['src'] ?? '';
        if (src.isNotEmpty) {
          return VideoSource(
            videoUrl: src.startsWith('//') ? 'https:$src' : src,
            quality: videoEl.attributes['quality'] ?? videoEl.attributes['label'] ?? 'auto',
            format: 'mp4',
          );
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error parsing video source: $e');
      return null;
    }
  }

  static String _detectQuality(String content) {
    if (content.contains('1080') || content.contains('fullhd')) return '1080p';
    if (content.contains('720') || content.contains('hd')) return '720p';
    if (content.contains('480')) return '480p';
    if (content.contains('360')) return '360p';
    return 'auto';
  }

  static List<Category> parseCategories(dom.Document document) {
    final categories = <Category>[];
    
    try {
      final categoryElements = document.querySelectorAll(
        '.category-item, .cat-item, [class*="category"] a, .categories a'
      );

      for (final element in categoryElements) {
        try {
          final name = element.text.trim();
          final href = element.attributes['href'] ?? '';
          
          if (name.isNotEmpty) {
            categories.add(Category(
              id: href.split('/').lastOrNull ?? categories.length.toString(),
              name: name,
              thumbnailUrl: null,
            ));
          }
        } catch (_) {
          continue;
        }
      }
    } catch (e) {
      debugPrint('Error parsing categories: $e');
    }
    
    return categories;
  }

  static List<Tag> parseTags(dom.Document document) {
    final tags = <Tag>[];
    
    try {
      final tagElements = document.querySelectorAll('.tag-item, a[class*="tag"], .tags a');
      
      for (final element in tagElements) {
        final name = element.text.trim();
        if (name.isNotEmpty) {
          tags.add(Tag(
            id: tags.length.toString(),
            name: name,
          ));
        }
      }
    } catch (_) {}
    
    return tags;
  }

  static Map<String, int> parsePagination(dom.Document document) {
    try {
      final paginationEl = document.querySelector('.pagination, .paging, [class*="pagination"]');
      if (paginationEl != null) {
        final pages = paginationEl.querySelectorAll('a, li, span').length;
        final totalMatch = RegExp(r'(\d+)').firstMatch(paginationEl.text);
        
        return {
          'pages': pages > 0 ? pages : 1,
          'total': totalMatch != null ? int.tryParse(totalMatch.group(1)!) ?? 100 : 100,
        };
      }
    } catch (_) {}
    
    return {'pages': 1, 'total': 100};
  }

  static void debugPrint(String message) {
    // No-op in release mode
    assert(() {
      print(message);
      return true;
    }());
  }
}
