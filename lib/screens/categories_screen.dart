import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category_model.dart';
import '../providers/video_provider.dart';
import '../widgets/shimmer_loading.dart';
import 'home_screen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VideoProvider>().loadCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Categories',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search categories...',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value.toLowerCase());
              },
            ),
          ),
        ),
      ),
      body: Consumer<VideoProvider>(
        builder: (context, provider, _) {
          if (provider.categories.isEmpty && !provider.isLoading) {
            return _buildEmptyState();
          }

          final filteredCategories = _searchQuery.isEmpty
              ? provider.categories
              : provider.categories
                  .where((cat) => cat.name.toLowerCase().contains(_searchQuery))
                  .toList();

          if (provider.isLoading && filteredCategories.isEmpty) {
            return _buildShimmerGrid();
          }

          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: filteredCategories.length,
            itemBuilder: (context, index) {
              final category = filteredCategories[index];
              return _CategoryCard(category: category);
            },
          );
        },
      ),
    );
  }

  Widget _buildShimmerGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => ShimmerLoading(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.category_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No categories found',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final Category category;

  const _CategoryCard({required this.category});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          // Navigate to category videos
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Opening ${category.name}...')),
          );
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Gradient background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _getGradientColor(category.id.hashCode % 5),
                    _getGradientColor((category.id.hashCode + 2) % 5).withOpacity(0.7),
                  ],
                ),
              ),
            ),
            
            // Content
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _getCategoryIcon(category.name),
                      size: 36,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      category.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        shadows: [
                          Shadow(blurRadius: 4, color: Colors.black26),
                        ],
                      ),
                    ),
                    if (category.videoCount > 0) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${category.videoCount} videos',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getGradientColor(int index) {
    final colors = [
      Colors.red.shade500,
      Colors.purple.shade500,
      Colors.blue.shade500,
      Colors.teal.shade500,
      Colors.orange.shade500,
    ];
    return colors[index.abs() % colors.length];
  }

  IconData _getCategoryIcon(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('amateur')) return Icons.person;
    if (lowerName.contains('hd') || lowerName.contains('1080')) return Icons.hd;
    if (lowerName.contains('teen')) return Icons.face;
    if (lowerName.contains('mature')) return Icons.elderly;
    if (lowerName.contains('asian')) return Icons.public;
    if (lowerName.contains('latina')) return Icons.woman;
    if (lowerName.contains('lesbian')) return Icons.female;
    if (lowerName.contains('anal')) return Icons.donut_large;
    if (lowerName.contains('blowjob')) return Icons.mic;
    if (lowerName.contains('hardcore')) return Icons.whatshot;
    return Icons.movie_filter;
  }
}
