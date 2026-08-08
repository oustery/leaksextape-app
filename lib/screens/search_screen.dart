import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/search_model.dart';
import '../models/video_model.dart';
import '../providers/video_provider.dart';
import '../widgets/video_card_widget.dart';
import '../widgets/shimmer_loading.dart';
import '../services/database_service.dart';
import 'video_player_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  late TabController _tabController;
  String _sortBy = 'relevance';
  bool _isSearching = false;
  List<SearchHistoryItem> _searchHistory = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSearchHistory();
    
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _searchHistory.isEmpty) {
        _loadSearchHistory();
      }
    });

    _searchController.addListener(() {
      setState(() {
        _isSearching = _searchController.text.isNotEmpty;
      });
    });
  }

  Future<void> _loadSearchHistory() async {
    try {
      final db = DatabaseService();
      final history = await db.getSearchHistory(limit: 10);
      if (mounted) {
        setState(() {
          _searchHistory = history;
        });
      }
    } catch (e) {
      debugPrint('Error loading search history: $e');
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    // Save to history
    try {
      final db = DatabaseService();
      await db.addSearchHistory(query);
    } catch (_) {}

    // Perform search
    final params = SearchParams(query: query.trim(), sortBy: _sortBy);
    await context.read<VideoProvider>().searchVideos(params);

    // Switch to results tab
    _tabController.animateTo(1);
  }

  void _clearHistory() async {
    try {
      final db = DatabaseService();
      await db.clearSearchHistory();
      setState(() {
        _searchHistory = [];
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _buildSearchField(),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Suggestions'),
            Tab(text: 'Results'),
          ],
        ),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                context.read<VideoProvider>().clearSearch();
              },
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSuggestionsTab(),
          _buildResultsTab(),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      focusNode: _focusNode,
      decoration: InputDecoration(
        hintText: 'Search videos...',
        border: InputBorder.none,
        hintStyle: TextStyle(color: Colors.grey[400]),
        suffixIcon: IconButton(
          icon: const Icon(Icons.tune, size: 20),
          onPressed: _showSortOptions,
        ),
      ),
      textInputAction: TextInputAction.search,
      onSubmitted: _performSearch,
    );
  }

  Widget _buildSuggestionsTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // Trending searches section
        _buildSectionHeader('Trending', Icons.trending_up),
        ..._buildTrendingItems(),
        
        const Divider(height: 32),
        
        // Search history section
        if (_searchHistory.isNotEmpty) ...[
          _buildSectionHeader('Recent Searches', Icons.history, onClear: _clearHistory),
          ..._searchHistory.map((item) => ListTile(
            leading: const Icon(Icons.history, size: 20),
            title: Text(item.query, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () async {
                try {
                  final db = DatabaseService();
                  await db.removeSearchHistoryItem(int.parse(item.id));
                  _loadSearchHistory();
                } catch (_) {}
              },
            ),
            onTap: () {
              _searchController.text = item.query;
              _performSearch(item.query);
            },
          )),
        ] else if (!_isSearching)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.search_off, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text('No recent searches', style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildTrendingItems() {
    final trending = ['trending', 'new', 'popular', 'HD', 'amateur'];
    return trending.map((term) => ListTile(
      leading: const Icon(Icons.trending_up, size: 20, color: Colors.orange),
      title: Text(term),
      onTap: () {
        _searchController.text = term;
        _performSearch(term);
      },
    )).toList();
  }

  Widget _buildSectionHeader(String title, IconData icon, {VoidCallback? onClear}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const Spacer(),
          if (onClear != null)
            TextButton(
              onPressed: onClear,
              child: const Text('Clear', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildResultsTab() {
    return Consumer<VideoProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return _buildShimmerList();
        }

        if (provider.hasError && !provider.hasSearchResults) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.search_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(provider.errorMessage!, textAlign: TextAlign.center),
              ],
            ),
          );
        }

        if (!provider.hasSearchResults && !_isSearching) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.movie_filter_outlined, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text('Search for videos', style: TextStyle(color: Colors.grey[500])),
              ],
            ),
          );
        }

        if (!provider.hasSearchResults && _isSearching) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.find_in_page_outlined, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text('No results found for "${_searchController.text}"',
                    style: TextStyle(color: Colors.grey[500])),
              ],
            ),
          );
        }

        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollEndNotification &&
                notification.metrics.pixels >= notification.metrics.maxScrollExtent - 200) {
              provider.loadMoreSearchResults();
            }
            return false;
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: provider.hasMorePages 
                ? provider.searchResults.length + 1 
                : provider.searchResults.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              if (index == provider.searchResults.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              
              final video = provider.searchResults[index];
              return VideoCardHorizontal(
                video: video,
                onTap: () => _openVideo(video),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildShimmerList() {
    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, __) => const HorizontalVideoCardShimmer(),
    );
  }

  void _showSortOptions() {
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
                  'Sort By',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              ...['relevance', 'date', 'views', 'rating'].map((option) => ListTile(
                title: Text(option.capitalize()),
                trailing: _sortBy == option ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
                onTap: () {
                  setState(() => _sortBy = option);
                  Navigator.pop(context);
                  if (_searchController.text.isNotEmpty) {
                    _performSearch(_searchController.text);
                  }
                },
              )),
            ],
          ),
        );
      },
    );
  }

  void _openVideo(VideoItem video) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(videoId: video.id, video: video),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _tabController.dispose();
    super.dispose();
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
