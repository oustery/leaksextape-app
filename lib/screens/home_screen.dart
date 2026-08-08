import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/video_model.dart';
import '../providers/video_provider.dart';
import '../widgets/video_card_widget.dart';
import '../widgets/shimmer_loading.dart';
import 'video_player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  void _loadInitialData() {
    context.read<VideoProvider>().loadLatestVideos();
    context.read<VideoProvider>().loadCategories();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<VideoProvider>().loadMoreVideos();
    }
  }

  Future<void> _onRefresh() async {
    await context.read<VideoProvider>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppConstants.appName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _openSearch(context),
          ),
        ],
      ),
      body: Consumer<VideoProvider>(
        builder: (context, provider, _) {
          return RefreshIndicator(
            onRefresh: _onRefresh,
            child: _buildBody(provider),
          );
        },
      ),
    );
  }

  Widget _buildBody(VideoProvider provider) {
    if (provider.isLoading && provider.videos.isEmpty) {
      return _buildShimmerGrid();
    }

    if (provider.hasError && provider.videos.isEmpty) {
      return _buildErrorWidget(provider.errorMessage!);
    }

    if (!provider.hasVideos) {
      return _buildEmptyState();
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: provider.hasMorePages ? provider.videos.length + 1 : provider.videos.length,
      itemBuilder: (context, index) {
        if (index == provider.videos.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        
        final video = provider.videos[index];
        return VideoCardWidget(
          video: video,
          onTap: () => _openVideoPlayer(context, video),
        );
      },
    );
  }

  Widget _buildShimmerGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => const VideoCardShimmer(),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.read<VideoProvider>().refresh(),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.video_library_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No videos found',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  void _openSearch(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SearchScreen()),
    );
  }

  void _openVideoPlayer(BuildContext context, VideoItem video) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(videoId: video.id, video: video),
      ),
    );
  }
}

// Import for AppConstants
class AppConstants {
  static const String appName = 'LeakSexTape';
}
