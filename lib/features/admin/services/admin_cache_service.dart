import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

/// Service de cache local pour les statistiques admin
class AdminCacheService {
  static Database? _database;
  static final AdminCacheService instance = AdminCacheService._init();
  
  AdminCacheService._init();
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('admin_stats.db');
    return _database!;
  }
  
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }
  
  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE admin_stats (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT UNIQUE NOT NULL,
        value TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    
    await db.execute('''
      CREATE TABLE admin_alerts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        alert_data TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
  }
  
  /// Sauvegarder les statistiques
  Future<void> saveStats(Map<String, dynamic> stats) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    await db.insert(
      'admin_stats',
      {
        'key': 'dashboard_stats',
        'value': jsonEncode(stats),
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  /// Récupérer les statistiques
  Future<Map<String, dynamic>?> getStats() async {
    final db = await database;
    
    final result = await db.query(
      'admin_stats',
      where: 'key = ?',
      whereArgs: ['dashboard_stats'],
      limit: 1,
    );
    
    if (result.isNotEmpty) {
      return jsonDecode(result.first['value'] as String);
    }
    return null;
  }
  
  /// Sauvegarder les données du graphique
  Future<void> saveChartData(List<double> newUsers, List<double> retention) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    await db.insert(
      'admin_stats',
      {
        'key': 'chart_data',
        'value': jsonEncode({
          'newUsers': newUsers,
          'retention': retention,
        }),
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  /// Récupérer les données du graphique
  Future<Map<String, List<double>>?> getChartData() async {
    final db = await database;
    
    final result = await db.query(
      'admin_stats',
      where: 'key = ?',
      whereArgs: ['chart_data'],
      limit: 1,
    );
    
    if (result.isNotEmpty) {
      final data = jsonDecode(result.first['value'] as String);
      return {
        'newUsers': (data['newUsers'] as List).cast<double>(),
        'retention': (data['retention'] as List).cast<double>(),
      };
    }
    return null;
  }
  
  /// Vérifier si le cache est valide (moins de 5 minutes)
  Future<bool> isCacheValid() async {
    final db = await database;
    
    final result = await db.query(
      'admin_stats',
      where: 'key = ?',
      whereArgs: ['dashboard_stats'],
      limit: 1,
    );
    
    if (result.isEmpty) return false;
    
    final updatedAt = result.first['updated_at'] as int;
    final age = DateTime.now().millisecondsSinceEpoch - updatedAt;
    
    // Cache valide pendant 5 minutes (300000 ms)
    return age < 300000;
  }
  
  /// Effacer le cache
  Future<void> clearCache() async {
    final db = await database;
    await db.delete('admin_stats');
    await db.delete('admin_alerts');
  }
  
  /// Fermer la base de données
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
