import 'package:flutter/foundation.dart' show debugPrint;
import 'package:html/dom.dart' as dom;
import '../models/video_model.dart';
import '../models/category_model.dart';
import 'constants.dart';

/// Enhanced HTML Parser with robust error handling and validation
class HtmlParserUtil {
  // Constants for validation
  static const int _maxTitleLength = 200;
  static const int _maxVideosPerPage = 50;
  static const Set<String> _invalidSchemes = {'javascript', 'data', 'mailto', 'tel'};
  static final RegExp _validVideoExtensions = RegExp(r'\.(mp4|webm|m3u8|mkv)(\?|$)', caseSensitive: false);
  static final RegExp _numericOnly = RegExp(r'^[\d\s.,]+$');

  /// Parse video list from HTML document with fallback strategies
  static List<VideoItem> parseVideoList(dom.Document document) {
    final videos = <VideoItem>[];
    
    try {
      // Strategy 1: Try specific video item selectors (more precise)
      final videoElements = document.querySelectorAll(
        '.video-item, .thumb-item, .video-block, .video-thumb, .thumb'
      );

      for (final element in videoElements.take(_maxVideosPerPage)) {
        try {
          final video = _parseVideoElement(element);
          if (video != null && video.id.isNotEmpty && _isValidVideoId(video.id)) {
            // Avoid duplicates
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

      // Strategy 2: Fallback to links with video patterns
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
          } catch (e, stackTrace) {
            debugPrint('HtmlParser: Error parsing link: $e');
            if (kDebugMode) {
              debugPrint('Stack: $stackTrace');
            }
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

  /// Parse single video element with enhanced extraction
  static VideoItem? _parseVideoElement(dom.Element element) {
    try {
      // Extract ID from href or data attribute
      String? id;
      final anchor = element.querySelector('a') ?? 
                     (element.localName == 'a' ? element : null);
      
      if (anchor != null) {
        final href = anchor.attributes['href'] ?? '';
        id = _extractVideoId(href);
        
        // If no ID from pattern, use last path segment
        if ((id == null || id.isEmpty) && href.isNotEmpty) {
          id = href.split('/').lastWhere(
            (segment) => segment.isNotEmpty,
            orElse: () => '',
          ).replaceAll(RegExp(r'\.html?$'), '');
        }
      } else {
        id = element.attributes['data-id'] ?? element.attributes['id'];
      }

      // Extract title safely
      String title = _extractTitle(element, anchor);

      // Validate required fields
      if (id == null || id.isEmpty || title.isEmpty) return null;
      
      // Sanitize inputs
      id = _sanitizeString(id, maxLength: 50);
      title = _sanitizeString(title, maxLength: _maxTitleLength);

      return VideoItem(
        id: id,
        title: title,
        thumbnailUrl: _extractThumbnail(element),
        duration: _extractDuration(element),
        views: _extractViews(element),
        rating: _extractRating(element),
        dateAdded: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      debugPrint('HtmlParser: Error in _parseVideoElement: $e');
      return null;
    }
  }

  /// Parse video from link element with safe string handling
  static VideoItem? _parseVideoFromLink(dom.Element link) {
    try {
      final href = link.attributes['href'] ?? '';
      if (href.isEmpty) return null;

      final id = _extractVideoId(href);
      if (id == null || id.isEmpty) return null;
      
      // Safe title extraction - FIX: RangeError prevention
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
      debugPrint('HtmlParser: Error in _parseVideoFromLink: $e');
      return null;
    }
  }

  /// Parse video source URL with validation - FIX: Hardcoded URL removed
  static VideoSource? parseVideoSource(dom.Document document, String videoId) {
    try {
      // Method 1: Extract from script tags (flashvars/player config)
      final source = _extractSourceFromScripts(document);
      if (source != null) return source;

      // Method 2: Look for iframe embed sources
      final iframe = document.querySelector(
        'iframe[src*="player"], iframe[src*="embed"], iframe[src*="video"]'
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

      return null;
    } catch (e, stackTrace) {
      debugPrint('HtmlParser: Error parsing video source: $e');
      if (kDebugMode) {
        debugPrint('Stack: $stackTrace');
      }
      return null;
    }
  }

  /// Extract video source from script tags with multiple regex patterns
  static VideoSource? _extractSourceFromScripts(dom.Document document) {
    final scripts = document.querySelectorAll('script:not([src])');
    
    for (final script in scripts) {
      final content = script.text;
      
      if (!content.contains('flashvars') && 
          !content.contains('video_url') && 
          !content.contains('source')) {
        continue;
      }

      // Multiple URL extraction patterns
      final urlPatterns = [
        // Pattern 1: video_url = "..." or video_url: "..."
        RegExp(r'video_url[\s]*[=:][\s]*["\x27]([^\x22\x27]+)["\x27]', caseSensitive: false),
        // Pattern 2: source file with mp4 extension
        RegExp(r'source[\s]*[=:][\s]*["\x27]([^\x22\x27]*\.mp4[^\x22\x27]*)["\x27]', caseSensitive: false),
        // Pattern 3: file = "..."
        RegExp(r'\bfile\b[\s]*[=:][\s]*["\x27]([^\x22\x27]+)["\x27]', caseSensitive: false),
        // Pattern 4: Access token pattern
        RegExp(r'v-acctoken=([^&"\s\x27]+)', caseSensitive: false),
        // Pattern 5: Single-quoted MP4 URLs
        RegExp(r"\x27([^\x27]*\.mp4(?:\?[^\x27]*)?)\x27", caseSensitive: false),
        // Pattern 6: Double-quoted URLs with common domains
        RegExp(r'"(https?:\/\/[^"]*\.(?:mp4|webm|m3u8)[^"]*)"', caseSensitive: false),
      ];

      for (final pattern in urlPatterns) {
        try {
          final match = pattern.firstMatch(content);
          if (match != null) {
            var videoUrl = match.group(1) ?? '';
            
            if (videoUrl.isEmpty) continue;
            
            // Process relative URLs - FIX: Use AppConstants.baseUrl instead of hardcoded
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
          debugPrint('HtmlParser: Regex pattern error: $e');
          continue;
        }
      }
    }
    
    return null;
  }

  /// Parse categories with deduplication
  static List<Category> parseCategories(dom.Document document) {
    final categories = <Category>[];
    final seenNames = <String>{};
    
    try {
      final categoryElements = document.querySelectorAll(
        '.category-item, .cat-item, [class*="category"] a, .categories a'
      );

      for (final element in categoryElements) {
        try {
          final name = element.text.trim();
          final href = element.attributes['href'] ?? '';
          
          // Validate and deduplicate
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
          debugPrint('HtmlParser: Error parsing category: $e');
          continue;
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
          
          // Validate tag name
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

  /// Parse pagination info with safe defaults - FIX: Force unwrap removed
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
      
      // Extract total count from text
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
      
      // Fallback: find any large number in text
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
    
    // Common video URL patterns
    final patterns = [
      RegExp(r'/(?:video|v|watch|play)/(\d+)'),
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
    // Should be numeric or alphanumeric, reasonable length
    return id.length <= 20 && 
           RegExp(r'^[\w\-]+$').hasMatch(id);
  }

  /// Extract title from element with multiple fallbacks
  static String _extractTitle(dom.Element element, dom.Element? anchor) {
    // Try specific title elements first
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
    
    // Fallback to anchor attributes
    if (anchor != null) {
      return anchor.attributes['title'] ?? 
             anchor.attributes['alt'] ?? 
             anchor.attributes['aria-label'] ?? '';
    }
    
    return '';
  }

  /// Extract thumbnail URL with data-src support
  static String _extractThumbnail(dom.Element element) {
    final img = element.querySelector('img');
    if (img == null) return '';
    
    // Priority order: data-src → data-thumb → src → data-lazy-src
    final sources = [
      img.attributes['data-src'],
      img.attributes['data-thumb'],
      img.attributes['src'],
      img.attributes['data-lazy-src'],
      img.attributes['data-original'],
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
        // Validate duration format (e.g., "12:34", "1:23:45")
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
        final text = el.text.replaceAll(',', '').replaceAll('.', '');
        final cleaned = text.replaceAll(RegExp(r'[^0-9]'), '');
        final views = int.tryParse(cleaned);
        if (views != null && views >= 0) return views;
      }
    }
    
    return 0;
  }

  /// Extract rating as double (0-100 or 0-5 scale)
  static double _extractRating(dom.Element element) {
    final selectors = [
      '.rating', '.stars', '.score', '.percent',
      '[class*="rating"]', '[class*="percent"]',
      '[data-rating]',
    ];
    
    for (final selector in selectors) {
      final el = element.querySelector(selector);
      if (el != null) {
        let text = el.text.replaceAll('%', '').trim();
        text = text.replaceAll(RegExp(r'[^\d.]'), '');
        final rating = double.tryParse(text);
        if (rating != null && rating >= 0) {
          // Normalize to 0-100 scale if needed
          return rating <= 5 ? rating * 20 : rating;
        }
      }
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
    return 'mp4'; // Default assumption
  }

  /// Normalize URL - FIX: Uses AppConstants instead of hardcoded domain
  static String _normalizeUrl(String url) {
    if (url.isEmpty) return url;
    
    // Protocol-relative URL
    if (url.startsWith('//')) {
      return 'https:$url';
    }
    
    // Absolute path (relative to domain)
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
    
    // Basic scheme check
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    
    // Block invalid schemes
    if (uri.hasScheme && _invalidSchemes.contains(uri.scheme.toLowerCase())) {
      return false;
    }
    
    // Must be http(s) or protocol-relative
    if (uri.hasScheme && !['http', 'https'].contains(uri.scheme.toLowerCase())) {
      return false;
    }
    
    // For direct video files, check extension or known patterns
    if (_validVideoExtensions.hasMatch(url)) {
      return true;
    }
    
    // Allow embed/player URLs
    if (url.contains('embed') || url.contains('player') || url.contains('stream')) {
      return true;
    }
    
    // Allow if it looks like a full URL with domain
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
      'thumbnail',
      'loading',
      'spacer',
      'gif', // Animated loading GIFs
    ];
    
    final lowerUrl = url.toLowerCase();
    return placeholderPatterns.any((pattern) => lowerUrl.contains(pattern));
  }

  /// Sanitize string input
  static String _sanitizeString(String input, {int maxLength = 100}) {
    if (input.isEmpty) return input;
    
    // Trim whitespace
    var sanitized = input.trim();
    
    // Truncate if too long
    if (sanitized.length > maxLength) {
      sanitized = sanitized.substring(0, maxLength);
    }
    
    // Remove control characters except newlines/tabs
    sanitized = sanitized.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');
    
    return sanitized;
  }

  /// Extract category ID from href
  static String _extractCategoryId(String href, int fallbackIndex) {
    if (href.isEmpty) return fallbackIndex.toString();
    
    // Try to extract slug or ID from URL
    final segments = href.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isNotEmpty) {
      final lastSegment = segments.last;
      // Return slug without file extension
      return lastSegment.replaceAll(RegExp(r'\.html?$'), '');
    }
    
    return fallbackIndex.toString();
  }
}
