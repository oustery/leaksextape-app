import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/video_model.dart';
import '../models/search_model.dart';
import 'constants.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.databaseName);
    
    return openDatabase(
      path,
      version: AppConstants.databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE favorites (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        thumbnail_url TEXT NOT NULL,
        duration TEXT,
        views INTEGER DEFAULT 0,
        rating REAL DEFAULT 0,
        date_added TEXT,
        preview_url,
        channel,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE watch_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        video_id TEXT NOT NULL,
        title TEXT NOT NULL,
        thumbnail_url TEXT NOT NULL,
        duration TEXT,
        watched_at TEXT DEFAULT CURRENT_TIMESTAMP,
        progress_seconds INTEGER DEFAULT 0,
        UNIQUE(video_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE search_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        query TEXT NOT NULL UNIQUE,
        searched_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE favorites ADD COLUMN preview_url TEXT');
      await db.execute('ALTER TABLE favorites ADD COLUMN channel TEXT');
    }
  }

  // Favorites operations
  Future<void> addToFavorites(VideoItem video) async {
    final db = await database;
    await db.insert(
      'favorites',
      video.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeFromFavorites(String videoId) async {
    final db = await database;
    await db.delete(
      'favorites',
      where: 'id = ?',
      whereArgs: [videoId],
    );
  }

  Future<bool> isFavorite(String videoId) async {
    final db = await database;
    final result = await db.query(
      'favorites',
      where: 'id = ?',
      whereArgs: [videoId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<List<VideoItem>> getFavorites({int limit = 50, int offset = 0}) async {
    final db = await database;
    final results = await db.query(
      'favorites',
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );
    return results.map((map) => VideoItem.fromJson(map)).toList();
  }

  Future<int> getFavoritesCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM favorites');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> clearFavorites() async {
    final db = await database;
    await db.delete('favorites');
  }

  // Watch history operations
  Future<void> addToWatchHistory(VideoItem video, {int progressSeconds = 0}) async {
    final db = await database;
    await db.insert(
      'watch_history',
      {
        'video_id': video.id,
        'title': video.title,
        'thumbnail_url': video.thumbnailUrl,
        'duration': video.duration,
        'progress_seconds': progressSeconds,
        'watched_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getWatchHistory({int limit = 20}) async {
    final db = await database;
    return await db.query(
      'watch_history',
      orderBy: 'watched_at DESC',
      limit: limit,
    );
  }

  Future<void> clearWatchHistory() async {
    final db = await database;
    await db.delete('watch_history');
  }

  Future<void> updateProgress(String videoId, int seconds) async {
    final db = await database;
    await db.update(
      'watch_history',
      {'progress_seconds': seconds},
      where: 'video_id = ?',
      whereArgs: [videoId],
    );
  }

  // Search history operations
  Future<void> addSearchHistory(String query) async {
    final db = await database;
    await db.insert(
      'search_history',
      {
        'query': query.trim(),
        'searched_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<SearchHistoryItem>> getSearchHistory({int limit = 10}) async {
    final db = await database;
    final results = await db.query(
      'search_history',
      orderBy: 'searched_at DESC',
      limit: limit,
    );
    return results.map((map) => SearchHistoryItem(
      id: map['id'].toString(),
      query: map['query'],
      searchedAt: DateTime.parse(map['searched_at']),
    )).toList();
  }

  Future<void> clearSearchHistory() async {
    final db = await database;
    await db.delete('search_history');
  }

  Future<void> removeSearchHistoryItem(int id) async {
    final db = await database;
    await db.delete('search_history', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
