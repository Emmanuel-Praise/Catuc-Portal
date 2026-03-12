import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DataCacheService {
  static Database? _db;

  const DataCacheService();

  static Future<void> init() async {
    if (kIsWeb) return;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'data_cache.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cache (
            cache_key TEXT PRIMARY KEY,
            data TEXT,
            timestamp INTEGER
          )
        ''');
      },
    );
  }

  Future<void> cacheData(String key, Map<String, dynamic> data) async {
    if (_db == null) return;
    await _db!.insert(
      'cache',
      {
        'cache_key': key,
        'data': jsonEncode(data),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getCachedData(String key, {Duration? maxAge}) async {
    if (_db == null) return null;

    final results = await _db!.query(
      'cache',
      where: 'cache_key = ?',
      whereArgs: [key],
    );

    if (results.isEmpty) return null;

    final item = results.first;
    final timestamp = item['timestamp'] as int;

    if (maxAge != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - timestamp > maxAge.inMilliseconds) {
        // Cache expired
        return null;
      }
    }

    try {
      return jsonDecode(item['data'] as String) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Cache parsing error: $e');
      return null;
    }
  }

  Future<void> invalidateCache(String key) async {
    if (_db == null) return;
    await _db!.delete('cache', where: 'cache_key = ?', whereArgs: [key]);
  }

  Future<void> clearAllCache() async {
    if (_db == null) return;
    await _db!.delete('cache');
  }
}
