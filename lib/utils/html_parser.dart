import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:html/dom.dart' as dom;
import '../models/video_model.dart';
import '../models/category_model.dart';
import 'constants.dart';

/// Enhanced HTML Parser for leak-sex-tape.com with robust error handling
class HtmlParserUtil {
  // Constants for validation
  static const int _maxTitleLength = 200;
  static const int _maxVideosPerPage = 50;
  static final Set<String> _invalidSchemes = {'javascript', 'data', 'mailto', 'tel'};
  static final RegExp _validVideoExtensions = RegExp(r'\.(mp4|webm|m3u8|mkv)(\?|$)', caseSensitive: false);
  static final RegExp _numericOnly = RegExp(r'^[\d\s.,]+$');

  /// Parse video list from HTML document - OPTIMIZED for leak-sex-tape.com
  static List<VideoItem> parseVideoList(dom.Document document) {
    final videos = <VideoItem>[];
    
    try {
      // Strategy 1: Primary selector for leak-sex-tape.com (.item class)
      final videoElements = document.querySelectorAll('.item');

      for (final element in videoElements.take(_maxVideosPerPage)) {
        try {
          final video = _parseVideoItem(element);
          if (video != null && video.id.isNotEmpty && _isValidVideoId(video.id)) {
            if (!videos.any((v) => v.id == video.id)) {
              videos.add(video);
            }
          }
        } catch (e, stackTrace) {
          debugPrint('HtmlParser: Error parsing video element: $e');
          if (kDebugMode) {
            debugPrint('Stack: $stackTrace');
          }
          continue;
        }
      }

      // Strategy 2: Fallback to generic video selectors
      if (videos.isEmpty) {
        final fallbackElements = document.querySelectorAll(
          '.video-item, .thumb-item, .video-block, .video-thumb, [class*="video"]'
        );

        for (final element in fallbackElements.take(_maxVideosPerPage)) {
          try {
            final video = _parseVideoElementGeneric(element);
            if (video != null && 
                video.id.isNotEmpty && 
                !videos.any((v) => v.id == video.id)) {
              videos.add(video);
            }
          } catch (e) {
            continue;
          }
        }
      }

      // Strategy 3: Last resort - links with video patterns
      if (videos.isEmpty) {
        final links = document.querySelectorAll('a[href*="/video/"], a[href*="/v/"]');
        
        for (final link in links.take(_maxVideosPerPage)) {
          try {
            final video = _parseVideoFromLink(link);
            if (video != null && 
                video.id.isNotEmpty && 
                !videos.any((v) => v.id == video.id)) {
              videos.add(video);
            }
          } catch (e) {
            continue;
          }
        }
      }

      debugPrint('HtmlParser: Parsed ${videos.length} videos');
    } catch (e, stackTrace) {
      debugPrint('HtmlParser: Critical error parsing video list: $e');
      if (kDebugMode) {
        debugPrint('Stack: $stackTrace');
      }
    }
    
    return videos;
  }

  /// Parse video item - OPTIMIZED for leak-sex-tape.com structure
  static VideoItem? _parseVideoItem(dom.Element itemElement) {
    try {
      // Find the anchor tag with video link
      final anchor = itemElement.querySelector('a[href*="/video/"]');
      if (anchor == null) return null;

      final href = anchor.attributes['href'] ?? '';
      if (href.isEmpty) return null;

      // Extract video ID from URL: /video/1513/slug/
      final id = _extractVideoId(href);
      if (id == null || id.isEmpty) return null;

      // Extract title from <strong class="title"> or title attribute
      String title = '';
      final titleEl = itemElement.querySelector('strong.title');
      if (titleEl != null) {
        title = titleEl.text.trim();
      }
      if (title.isEmpty) {
        title = anchor.attributes['title'] ?? '';
      }
      if (title.isEmpty) return null;

      // Extract thumbnail - CRITICAL FIX: use data-original or data-webp
      String thumbnailUrl = '';
      final img = itemElement.querySelector('img.thumb, img[data-original], img[data-webp], img.lazy-load');
      if (img != null) {
        // Priority: data-webp (WebP is smaller) > data-original > src
        thumbnailUrl = img.attributes['data-webp'] ?? 
                       img.attributes['data-original'] ?? 
                       img.attributes['src'] ?? '';
        
        // Skip placeholder images (1x1 GIF)
        if (_isPlaceholderImage(thumbnailUrl)) {
          thumbnailUrl = '';
        }
      }

      // Extract duration from .duration
      String duration = '';
      final durationEl = itemElement.querySelector('.duration');
      if (durationEl != null) {
        duration = durationEl.text.trim();
      }

      // Extract views from .views (e.g., "574.8k" -> 574800)
      int views = 0;
      final viewsEl = itemElement.querySelector('.views');
      if (viewsEl != null) {
        views = _parseViewCount(viewsEl.text.trim());
      }

      // Extract rating from .rating (e.g., "84%" -> 84.0)
      double rating = 0.0;
      final ratingEl = itemElement.querySelector('.rating');
      if (ratingEl != null) {
        rating = _parseRating(ratingEl.text.trim());
      }

      return VideoItem(
        id: id,
        title: _sanitizeString(title, maxLength: _maxTitleLength),
        thumbnailUrl: _normalizeImageUrl(thumbnailUrl),
        duration: duration,
        views: views,
        rating: rating,
        dateAdded: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      debugPrint('HtmlParser: Error in _parseVideoItem: $e');
      return null;
    }
  }

  /// Generic video element parser for other site structures
  static VideoItem? _parseVideoElementGeneric(dom.Element element) {
    try {
      String? id;
      final anchor = element.querySelector('a') ?? 
                     (element.localName == 'a' ? element : null);
      
      if (anchor != null) {
        final href = anchor.attributes['href'] ?? '';
        id = _extractVideoId(href);
        
        if ((id == null || id.isEmpty) && href.isNotEmpty) {
          id = href.split('/').lastWhere(
            (segment) => segment.isNotEmpty,
            orElse: () => '',
          ).replaceAll(RegExp(r'\.html?$'), '');
        }
      } else {
        id = element.attributes['data-id'] ?? element.attributes['id'];
      }

      String title = _extractTitle(element, anchor);

      if (id == null || id.isEmpty || title.isEmpty) return null;
      
      return VideoItem(
        id: _sanitizeString(id, maxLength: 50),
        title: _sanitizeString(title, maxLength: _maxTitleLength),
        thumbnailUrl: _extractThumbnailGeneric(element),
        duration: _extractDuration(element),
        views: _extractViews(element),
        rating: _extractRating(element),
        dateAdded: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Parse video from link element (fallback)
  static VideoItem? _parseVideoFromLink(dom.Element link) {
    try {
      final href = link.attributes['href'] ?? '';
      if (href.isEmpty) return null;

      final id = _extractVideoId(href);
      if (id == null || id.isEmpty) return null;
      
      final rawText = link.text?.trim() ?? '';
      final title = rawText.isEmpty 
          ? (link.attributes['title'] ?? '')
          : (rawText.length > _maxTitleLength 
              ? '${rawText.substring(0, _maxTitleLength)}...' 
              : rawText);
      
      if (title.isEmpty) return null;

      return VideoItem(
        id: _sanitizeString(id, maxLength: 50),
        title: _sanitizeString(title, maxLength: _maxTitleLength),
        thumbnailUrl: '',
        duration: '',
        views: 0,
        rating: 0,
        dateAdded: '',
      );
    } catch (e) {
      return null;
    }
  }

  /// Parse video source URL - OPTIMIZED for leak-sex-tape.com
  static VideoSource? parseVideoSource(dom.Document document, String videoId) {
    try {
      // Method 1: Extract video_url from script tags (PRIMARY for leak-sex-tape.com)
      final source = _extractSourceFromFlashvars(document);
      if (source != null) return source;

      // Method 2: Look for iframe embed sources
      final iframe = document.querySelector(
        'iframe[src*="embed"], iframe[src*="player"], iframe[src*="video"]'
      );
      if (iframe != null) {
        final src = iframe.attributes['src'] ?? '';
        if (src.isNotEmpty && _isValidUrl(src)) {
          return VideoSource(videoUrl: src, quality: 'auto', format: 'embed');
        }
      }

      // Method 3: Direct <video> elements
      final videoEl = document.querySelector('video source[src], video[src]');
      if (videoEl != null) {
        final src = videoEl.attributes['src'] ?? '';
        if (src.isNotEmpty && _isValidUrl(src)) {
          final processedSrc = src.startsWith('//') ? 'https:$src' : src;
          return VideoSource(
            videoUrl: processedSrc,
            quality: videoEl.attributes['quality'] ?? 
                    videoEl.attributes['label'] ?? 'auto',
            format: 'mp4',
          );
        }
      }

      // Method 4: Fallback to embed URL pattern
      final embedUrl = '${AppConstants.baseUrl}/embed/$videoId';
      return VideoSource(videoUrl: embedUrl, quality: 'auto', format: 'embed');
      
    } catch (e, stackTrace) {
      debugPrint('HtmlParser: Error parsing video source: $e');
      if (kDebugMode) {
        debugPrint('Stack: $stackTrace');
      }
      return null;
    }
  }

  /// Extract video source from flashvars JavaScript - PRIMARY METHOD
  static VideoSource? _extractSourceFromFlashvars(dom.Document document) {
    final scripts = document.querySelectorAll('script:not([src])');
    
    for (final script in scripts) {
      final content = script.text;
      
      // Check if this script contains video-related data
      if (!content.contains('video_url') && 
          !content.contains('video_url:') &&
          !content.contains('get_file')) {
        continue;
      }

      // Pattern 1: video_url: 'URL' or video_url: "URL"
      final pattern1 = RegExp("video_url[\\s]*:[\\s]*['\"]([^'\"]+)['\"]", caseSensitive: false);
      final pattern2 = RegExp("video_url[\\s]*:[\\s]*['\"]([^'\"]*get_file[^'\"]*)['\"]", caseSensitive: false);
      final pattern3 = RegExp(r"'(https?://[^']*\.mp4[^']*)'", caseSensitive: false);
      final pattern4 = RegExp(r'"(https?://[^"]*\.mp4[^"]*)"', caseSensitive: false);
      final pattern5 = RegExp("embed['\"\\s/]+(\d+)", caseSensitive: false);
      
      final List<RegExp> patterns = [pattern1, pattern2, pattern3, pattern4, pattern5];

      for (final pattern in patterns) {
        try {
          final match = pattern.firstMatch(content);
          if (match != null) {
            var videoUrl = match.group(1) ?? '';
            
            if (videoUrl.isEmpty) continue;
            
            // If we got just an ID from embed pattern, construct full URL
            if (RegExp(r'^\d+$').hasMatch(videoUrl)) {
              videoUrl = '${AppConstants.baseUrl}/embed/$videoUrl';
            }
            
            // Process relative URLs
            videoUrl = _normalizeUrl(videoUrl);
            
            // Validate before returning
            if (videoUrl.isNotEmpty && _isValidVideoUrl(videoUrl)) {
              return VideoSource(
                videoUrl: videoUrl,
                quality: _detectQuality(content),
                format: _detectFormat(videoUrl),
              );
            }
          }
        } catch (e) {
          continue;
        }
      }
    }
    
    return null;
  }

  /// Parse categories - OPTIMIZED for leak-sex-tape.com
  static List<Category> parseCategories(dom.Document document) {
    final categories = <Category>[];
    final seenNames = <String>{};
    
    try {
      // Primary selector for leak-sex-tape.com
      final categoryElements = document.querySelectorAll(
        '.cat-title a, .list-categories-items a, [class*="cat"] a[href*="/categories/"]'
      );

      for (final element in categoryElements) {
        try {
          final name = element.text.trim();
          final href = element.attributes['href'] ?? '';
          
          // Validate and deduplicate
          if (name.isNotEmpty && 
              name.length < 100 && 
              !seenNames.contains(name.toLowerCase()) &&
              name != 'All') {  // Skip "All" filter link
            seenNames.add(name.toLowerCase());
            
            // Try to extract thumbnail from parent or sibling
            String? thumbnailUrl;
            final parent = element.parent;
            if (parent != null) {
              final img = parent.querySelector('img');
              if (img != null) {
                thumbnailUrl = img.attributes['data-original'] ?? 
                               img.attributes['src'] ?? null;
              }
            }
            
            categories.add(Category(
              id: _extractCategoryId(href, categories.length),
              name: name,
              thumbnailUrl: thumbnailUrl != null ? _normalizeImageUrl(thumbnailUrl) : null,
            ));
          }
        } catch (e) {
          debugPrint('HtmlParser: Error parsing category: $e');
          continue;
        }
      }
      
      // Fallback: generic category selectors
      if (categories.isEmpty) {
        final fallbackElements = document.querySelectorAll(
          '.category-item, .cat-item, [class*="category"] a, .categories a'
        );

        for (final element in fallbackElements) {
          try {
            final name = element.text.trim();
            final href = element.attributes['href'] ?? '';
            
            if (name.isNotEmpty && 
                name.length < 100 && 
                !seenNames.contains(name.toLowerCase())) {
              seenNames.add(name.toLowerCase());
              
              categories.add(Category(
                id: _extractCategoryId(href, categories.length),
                name: name,
                thumbnailUrl: null,
              ));
            }
          } catch (e) {
            continue;
          }
        }
      }
      
      debugPrint('HtmlParser: Parsed ${categories.length} categories');
    } catch (e, stackTrace) {
      debugPrint('HtmlParser: Error parsing categories: $e');
      if (kDebugMode) {
        debugPrint('Stack: $stackTrace');
      }
    }
    
    return categories;
  }

  /// Parse tags with basic validation
  static List<Tag> parseTags(dom.Document document) {
    final tags = <Tag>[];
    final seenNames = <String>{};
    
    try {
      final tagElements = document.querySelectorAll('.tag-item, a[class*="tag"], .tags a');
      
      for (final element in tagElements) {
        try {
          final name = element.text.trim();
          
          if (name.isNotEmpty && 
              name.length < 50 &&
              !seenNames.contains(name.toLowerCase())) {
            seenNames.add(name.toLowerCase());
            
            tags.add(Tag(
              id: tags.length.toString(),
              name: name,
            ));
          }
        } catch (e) {
          continue;
        }
      }
    } catch (e) {
      debugPrint('HtmlParser: Error parsing tags: $e');
    }
    
    return tags;
  }

  /// Parse pagination info with safe defaults
  static Map<String, int> parsePagination(dom.Document document) {
    const defaultResult = {'pages': 1, 'total': 100};
    
    try {
      final paginationEl = document.querySelector(
        '.pagination, .paging, [class*="pagination"], nav'
      );
      
      if (paginationEl == null) return defaultResult;
      
      final pageElements = paginationEl.querySelectorAll('a, li, span, button');
      final pages = pageElements.where((el) => 
        el.text.trim().isNotEmpty && _numericOnly.hasMatch(el.text.trim())
      ).length;
      
      int total = 100;
      final text = paginationEl.text;
      final totalMatches = RegExp(r'(?:total|of|results?)[:\s]*(\d+)', caseSensitive: false)
          .allMatches(text);
      
      if (totalMatches.isNotEmpty) {
        final lastMatch = totalMatches.last.group(1);
        if (lastMatch != null) {
          total = int.tryParse(lastMatch) ?? 100;
        }
      }
      
      if (total <= 0) {
        final numbers = RegExp(r'\b(\d{3,})\b').allMatches(text)
            .map((m) => int.tryParse(m.group(1) ?? '') ?? 0)
            .where((n) => n > total)
            .toList();
        if (numbers.isNotEmpty) {
          total = numbers.last;
        }
      }
      
      return {
        'pages': pages.clamp(1, 9999),
        'total': total.clamp(1, 99999),
      };
    } catch (e) {
      debugPrint('HtmlParser: Error parsing pagination: $e');
      return defaultResult;
    }
  }

  // ==================== HELPER METHODS ====================

  /// Extract and validate video ID from URL
  static String? _extractVideoId(String href) {
    if (href.isEmpty) return null;
    
    // Patterns for leak-sex-tape.com: /video/1513/slug/
    final patterns = [
      RegExp(r'/video/(\d+)'),           // /video/1513/slug/
      RegExp(r'/(?:v|watch|play)/(\d+)'), // Alternative patterns
      RegExp(r'[?&](?:v|id|video_id)=(\d+)'),
      RegExp(r'/(\d{4,})(?:\.html?|/|$)'),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(href);
      if (match != null) {
        return match.group(1);
      }
    }
    
    return null;
  }

  /// Check if video ID is valid
  static bool _isValidVideoId(String id) {
    if (id.isEmpty) return false;
    return id.length <= 20 && 
           RegExp(r'^[\w\-]+$').hasMatch(id);
  }

  /// Extract title from element with multiple fallbacks
  static String _extractTitle(dom.Element element, dom.Element? anchor) {
    final titleSelectors = [
      '.title',
      '.video-title',
      '.name',
      'h1', 'h2', 'h3', 'h4',
      '[class*="title"]',
      '[itemprop="name"]',
    ];
    
    for (final selector in titleSelectors) {
      final el = element.querySelector(selector);
      if (el != null && el.text.trim().isNotEmpty) {
        return el.text.trim();
      }
    }
    
    if (anchor != null) {
      return anchor.attributes['title'] ?? 
             anchor.attributes['alt'] ?? 
             anchor.attributes['aria-label'] ?? '';
    }
    
    return '';
  }

  /// Extract thumbnail URL - GENERIC version (for non-optimized parsing)
  static String _extractThumbnailGeneric(dom.Element element) {
    final img = element.querySelector('img');
    if (img == null) return '';
    
    final sources = [
      img.attributes['data-original'],  // leak-sex-tape.com specific
      img.attributes['data-webp'],      // WebP version
      img.attributes['data-src'],
      img.attributes['data-thumb'],
      img.attributes['src'],
      img.attributes['data-lazy-src'],
    ];
    
    for (final source in sources) {
      if (source != null && 
          source.isNotEmpty && 
          !_isPlaceholderImage(source)) {
        return _normalizeImageUrl(source);
      }
    }
    
    return '';
  }

  /// Extract duration text
  static String _extractDuration(dom.Element element) {
    final selectors = [
      '.duration', '.length', '.time',
      '[class*="duration"]', '[class*="time"]',
      'span.duration',
    ];
    
    for (final selector in selectors) {
      final el = element.querySelector(selector);
      if (el != null) {
        final text = el.text.trim();
        if (RegExp(r'^[\d:]+$').hasMatch(text) || 
            RegExp(r'^\d+\s*(min|sec|h)$', caseSensitive: false).hasMatch(text)) {
          return text;
        }
      }
    }
    
    return '';
  }

  /// Extract view count as integer
  static int _extractViews(dom.Element element) {
    final selectors = [
      '.views', '.view-count', '.hits',
      '[class*="views"]', '[class*="hits"]',
      '[data-views]',
    ];
    
    for (final selector in selectors) {
      final el = element.querySelector(selector);
      if (el != null) {
        return _parseViewCount(el.text.trim());
      }
    }
    
    return 0;
  }

  /// Parse view count string to integer (handles "574.8k", "1.2M", etc.)
  static int _parseViewCount(String text) {
    if (text.isEmpty) return 0;
    
    final cleaned = text.replaceAll(',', '').replaceAll('.', '').toLowerCase();
    final numericPart = cleaned.replaceAll(RegExp(r'[^\d]'), '');
    final views = int.tryParse(numericPart) ?? 0;
    
    // Handle multipliers
    if (text.contains('k')) {
      return (views * 1000).round();
    } else if (text.contains('m')) {
      return (views * 1000000).round();
    }
    
    return views;
  }

  /// Extract rating as double (0-100 scale)
  static double _extractRating(dom.Element element) {
    final selectors = [
      '.rating', '.stars', '.score', '.percent',
      '[class*="rating"]', '[class*="percent"]',
      '[data-rating]',
    ];
    
    for (final selector in selectors) {
      final el = element.querySelector(selector);
      if (el != null) {
        return _parseRating(el.text.trim());
      }
    }
    
    return 0.0;
  }

  /// Parse rating string to double (handles "84%", "4.5", etc.)
  static double _parseRating(String text) {
    if (text.isEmpty) return 0.0;
    
    var cleaned = text.replaceAll('%', '').trim();
    cleaned = cleaned.replaceAll(RegExp(r'[^\d.]'), '');
    final rating = double.tryParse(cleaned);
    
    if (rating != null && rating >= 0) {
      // Normalize to 0-100 scale if needed
      return rating <= 5 ? rating * 20 : rating;
    }
    
    return 0.0;
  }

  /// Detect video quality from content
  static String _detectQuality(String content) {
    final lowerContent = content.toLowerCase();
    
    if (lowerContent.contains('1080') || lowerContent.contains('fullhd') || lowerContent.contains('fhd')) {
      return '1080p';
    }
    if (lowerContent.contains('720') || lowerContent.contains('hd')) {
      return '720p';
    }
    if (lowerContent.contains('480') || lowerContent.contains('sd')) {
      return '480p';
    }
    if (lowerContent.contains('360')) {
      return '360p';
    }
    
    return 'auto';
  }

  /// Detect video format from URL
  static String _detectFormat(String url) {
    if (url.contains('.m3u8')) return 'hls';
    if (url.contains('.webm')) return 'webm';
    if (url.contains('.mkv')) return 'mkv';
    if (_validVideoExtensions.hasMatch(url)) return 'mp4';
    if (url.contains('embed') || url.contains('player')) return 'embed';
    return 'mp4';
  }

  /// Normalize URL
  static String _normalizeUrl(String url) {
    if (url.isEmpty) return url;
    
    if (url.startsWith('//')) {
      return 'https:$url';
    }
    
    if (url.startsWith('/') && !url.startsWith('//')) {
      return '${AppConstants.baseUrl}$url';
    }
    
    return url;
  }

  /// Normalize image URL for caching
  static String _normalizeImageUrl(String url) {
    if (url.startsWith('//')) {
      return 'https:$url';
    }
    return url;
  }

  /// Check if URL is valid for video playback
  static bool _isValidVideoUrl(String url) {
    if (url.isEmpty) return false;
    
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    
    if (uri.hasScheme && _invalidSchemes.contains(uri.scheme.toLowerCase())) {
      return false;
    }
    
    if (uri.hasScheme && !['http', 'https'].contains(uri.scheme.toLowerCase())) {
      return false;
    }
    
    if (_validVideoExtensions.hasMatch(url)) {
      return true;
    }
    
    if (url.contains('embed') || url.contains('player') || url.contains('stream')) {
      return true;
    }
    
    if (url.contains('get_file')) {  // leak-sex-tape.com specific
      return true;
    }
    
    if (uri.host.isNotEmpty && uri.host.contains('.')) {
      return true;
    }
    
    return false;
  }

  /// General URL validation
  static bool _isValidUrl(String url) {
    if (url.isEmpty) return false;
    
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    
    if (uri.hasScheme && _invalidSchemes.contains(uri.scheme.toLowerCase())) {
      return false;
    }
    
    return uri.host.isNotEmpty || url.startsWith('/');
  }

  /// Check if image URL is a placeholder
  static bool _isPlaceholderImage(String url) {
    final placeholderPatterns = [
      'placeholder',
      'default',
      'empty',
      'no-image',
      'loading',
      'spacer',
      'data:image/gif',  // Base64 placeholder GIF
      'R0lGODlh',       // Base64 encoded 1x1 GIF
    ];
    
    final lowerUrl = url.toLowerCase();
    return placeholderPatterns.any((pattern) => lowerUrl.contains(pattern));
  }

  /// Sanitize string input
  static String _sanitizeString(String input, {int maxLength = 100}) {
    if (input.isEmpty) return input;
    
    var sanitized = input.trim();
    
    if (sanitized.length > maxLength) {
      sanitized = sanitized.substring(0, maxLength);
    }
    
    sanitized = sanitized.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');
    
    return sanitized;
  }

  /// Extract category ID from href
  static String _extractCategoryId(String href, int fallbackIndex) {
    if (href.isEmpty) return fallbackIndex.toString();
    
    final segments = href.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isNotEmpty) {
      final lastSegment = segments.last;
      return lastSegment.replaceAll(RegExp(r'\.html?$'), '');
    }
    
    return fallbackIndex.toString();
  }
}
