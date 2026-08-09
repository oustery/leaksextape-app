import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:webview_flutter/webview_flutter.dart' as webview;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/video_model.dart';
import '../providers/video_provider.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../utils/constants.dart' show AppConstants;
import '../widgets/video_card_widget.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoId;
  final VideoItem? video;

  const VideoPlayerScreen({
    super.key,
    required this.videoId,
    this.video,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  webview.WebViewController? _webViewController;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isFavorite = false;
  bool _isEmbed = false;  // Track if using embed mode
  List<VideoQuality> _qualities = [];
  int _currentQualityIndex = 0;
  List<VideoItem> _relatedVideos = [];

  @override
  void initState() {
    super.initState();
    _checkFavoriteStatus();
    _loadVideoSource();
    _loadRelatedVideos();
    
    // Add to watch history
    if (widget.video != null) {
      _addToHistory(widget.video!);
    }
  }

  Future<void> _checkFavoriteStatus() async {
    try {
      final db = DatabaseService();
      final isFav = await db.isFavorite(widget.videoId);
      if (mounted) {
        setState(() => _isFavorite = isFav);
      }
    } catch (_) {}
  }

  Future<void> _loadVideoSource() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      final api = LeakSexTapeService();
      final source = await api.getVideoSource(widget.videoId);
      
      if (source != null && mounted) {
        final url = source.videoUrl;
        
        // Determine if this is an embed URL or direct video URL
        _isEmbed = source.format == 'embed' || url.contains('/embed/');
        
        if (_isEmbed) {
          debugPrint('VideoPlayer: Using WebView for embed URL');
          _initializeWebView(url);
        } else {
          debugPrint('VideoPlayer: Using video player for direct URL');
          _initializePlayer(url);
        }
        
        // Setup qualities
        _qualities = [
          VideoQuality(label: 'Auto', url: url),
          if (source.isHD)
            VideoQuality(label: source.quality, url: url),
          VideoQuality(label: '480p', url: url),
        ];
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  /// Initialize native video player for direct MP4/URLs
  void _initializePlayer(String url) {
    _videoController?.dispose();
    _chewieController?.dispose();

    _videoController = VideoPlayerController.networkUrl(Uri.parse(url));

    _videoController!.initialize().then((_) {
      if (!mounted) return;
      
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoController!.value.aspectRatio > 0 
            ? _videoController!.value.aspectRatio 
            : 16 / 9,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.red,
          handleColor: Colors.redAccent,
          bufferedColor: Colors.grey[300]!,
          backgroundColor: Theme.of(context).colorScheme.surface,
        ),
        placeholder: widget.video != null && widget.video!.thumbnailUrl.isNotEmpty
            ? CachedNetworkImage(imageUrl: widget.video!.thumbnailUrl)
            : null,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.white, size: 42),
                const SizedBox(height: 8),
                Text(
                  errorMessage,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _openInExternalBrowser,
                  child: const Text('Open in Browser', style: TextStyle(color: Colors.white70)),
                ),
              ],
            ),
          );
        },
      );

      setState(() {
        _isLoading = false;
        _isEmbed = false;
      });
    }).catchError((error) {
      debugPrint('VideoPlayer: Error initializing player: $error');
      if (mounted) {
        // Fallback to WebView if video player fails
        setState(() {
          _isEmbed = true;
          _isLoading = false;
        });
        _initializeWebView(url);
      }
    });
  }

  /// Initialize WebView for embed URLs
  void _initializeWebView(String url) {
    _webViewController = webview.WebViewController()
      ..setJavaScriptMode(webview.JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        webview.NavigationDelegate(
          onProgress: (int progress) {
            if (progress == 100 && mounted) {
              setState(() => _isLoading = false);
            }
          },
          onPageStarted: (String url) {
            debugPrint('WebView: Page started: $url');
            if (mounted) {
              setState(() => _isLoading = true);
            }
          },
          onPageFinished: (String url) {
            debugPrint('WebView: Page finished: $url');
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
          onWebResourceError: (webview.WebResourceError error) {
            debugPrint('WebView: Error: ${error.description}');
            if (mounted) {
              setState(() {
                _errorMessage = 'Failed to load video player';
                _isLoading = false;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(url));

    setState(() {
      _isEmbed = true;
      _isLoading = false;
    });
  }

  Future<void> _loadRelatedVideos() async {
    try {
      final provider = context.read<VideoProvider>();
      if (provider.videos.isNotEmpty) {
        setState(() {
          _relatedVideos = provider.videos.take(10).toList()
            .where((v) => v.id != widget.videoId)
            .toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleFavorite() async {
    if (widget.video == null) return;
    
    try {
      final db = DatabaseService();
      
      if (_isFavorite) {
        await db.removeFromFavorites(widget.videoId);
      } else {
        await db.addToFavorites(widget.video!);
      }
      
      setState(() => _isFavorite = !_isFavorite);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isFavorite ? 'Added to favorites' : 'Removed from favorites'),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (_) {}
  }

  Future<void> _shareVideo() async {
    final url = '${AppConstants.baseUrl}/video/${widget.videoId}/';
    
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  /// Open video in external browser as fallback
  Future<void> _openInExternalBrowser() async {
    final url = '${AppConstants.baseUrl}/video/${widget.videoId}/';
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error opening browser: $e');
    }
  }

  void _showQualitySelector() {
    if (_qualities.isEmpty) return;
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Select Quality',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              ...List.generate(_qualities.length, (index) {
                final quality = _qualities[index];
                return ListTile(
                  title: Text(quality.label),
                  trailing: index == _currentQualityIndex 
                      ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    setState(() => _currentQualityIndex = index);
                    Navigator.pop(context);
                    if (_isEmbed) {
                      _initializeWebView(quality.url);
                    } else {
                      _initializePlayer(quality.url);
                    }
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _openRelatedVideo(VideoItem video) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(videoId: video.id, video: video),
      ),
    );
  }

  Future<void> _addToHistory(VideoItem video) async {
    try {
      final db = DatabaseService();
      await db.addToWatchHistory(video);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: MediaQuery.of(context).size.width * 9 / 16,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildVideoArea(),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: _isFavorite ? Colors.red : null,
                ),
                onPressed: _toggleFavorite,
              ),
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: _shareVideo,
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'quality') {
                    _showQualitySelector();
                  } else if (value == 'browser') {
                    _openInExternalBrowser();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'quality', child: Text('Quality')),
                  const PopupMenuItem(value: 'browser', child: Text('Open in Browser')),
                ],
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    widget.video?.title ?? 'Loading...',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  
                  // Meta info
                  Row(
                    children: [
                      Icon(Icons.visibility_outlined, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text('${widget.video?.formattedViews ?? ''} views'),
                      const SizedBox(width: 16),
                      Icon(Icons.star, size: 16, color: Colors.amber[400]),
                      const SizedBox(width: 4),
                      Text('${widget.video?.rating.toStringAsFixed(1) ?? ''}'),
                      const SizedBox(width: 16),
                      Text(widget.video?.duration ?? '', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Tags
                  if (widget.video != null && widget.video!.tags.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.video!.tags.take(6).map((tag) {
                        return Chip(
                          label: Text(tag, style: const TextStyle(fontSize: 12)),
                          backgroundColor: Theme.of(context).colorScheme.surface,
                        );
                      }).toList(),
                    ),
                  
                  const SizedBox(height: 24),
                  
                  // Related videos section
                  Text(
                    'Related Videos',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          
          // Related videos list
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (_relatedVideos.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('No related videos')),
                  );
                }
                
                final video = _relatedVideos[index];
                return VideoCardHorizontal(
                  video: video,
                  onTap: () => _openRelatedVideo(video),
                );
              },
              childCount: _relatedVideos.isEmpty ? 1 : _relatedVideos.length,
            ),
          ),
          
          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      ),
    );
  }

  Widget _buildVideoArea() {
    if (_isLoading) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (_errorMessage != null && !_isEmbed) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.white54, size: 48),
              const SizedBox(height: 12),
              Text(_errorMessage!, style: const TextStyle(color: Colors.white54), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadVideoSource,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _openInExternalBrowser,
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Open in Browser', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
      );
    }

    // Show WebView for embed URLs
    if (_isEmbed && _webViewController != null) {
      return SizedBox(
        height: double.infinity,
        child: webview.WebViewWidget(controller: _webViewController!),
      );
    }

    // Show Chewie player for direct video URLs
    if (_chewieController != null && !_isEmbed) {
      return Chewie(controller: _chewieController!);
    }

    return Container(color: Colors.black);
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }
}
