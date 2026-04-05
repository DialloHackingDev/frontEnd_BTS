import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static Database? _db;
  static const int _version = 1;
  static const String _dbName = 'bts_local.db';

  static Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    return openDatabase(path, version: _version, onCreate: _onCreate);
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE auth (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE goals (
        id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        status TEXT DEFAULT 'pending',
        due_date TEXT,
        created_at TEXT NOT NULL,
        synced INTEGER DEFAULT 1,
        deleted INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE library (
        id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        type TEXT NOT NULL,
        url TEXT NOT NULL,
        description TEXT,
        category TEXT,
        created_at TEXT NOT NULL,
        synced INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE events (
        id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        type TEXT DEFAULT 'general',
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        conference_id INTEGER,
        created_by INTEGER,
        created_at TEXT NOT NULL,
        synced INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE conferences (
        id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        room_id TEXT NOT NULL,
        video_url TEXT,
        trainer_name TEXT,
        created_at TEXT NOT NULL,
        synced INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE pending_sync (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action TEXT NOT NULL,
        table_name TEXT NOT NULL,
        record_id INTEGER,
        data TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE dashboard_cache (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  // ── Auth ─────────────────────────────────────────────────
  static Future<void> saveAuth(String key, String value) async {
    final d = await db;
    await d.insert('auth', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<String?> getAuth(String key) async {
    final d = await db;
    final rows = await d.query('auth', where: 'key = ?', whereArgs: [key]);
    return rows.isNotEmpty ? rows.first['value'] as String? : null;
  }

  static Future<void> deleteAuth(String key) async {
    final d = await db;
    await d.delete('auth', where: 'key = ?', whereArgs: [key]);
  }

  static Future<void> clearAuth() async {
    final d = await db;
    await d.delete('auth');
  }

  // ── Goals ────────────────────────────────────────────────
  static Future<void> saveGoals(List<Map<String, dynamic>> goals) async {
    final d = await db;
    final batch = d.batch();
    for (final g in goals) {
      batch.insert('goals', {
        'id': g['id'],
        'title': g['title'],
        'description': g['description'],
        'status': g['status'] ?? 'pending',
        'due_date': g['due_date'] ?? g['dueDate'],
        'created_at': g['created_at'] ?? g['createdAt'] ?? DateTime.now().toIso8601String(),
        'synced': 1,
        'deleted': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Map<String, dynamic>>> getGoals() async {
    final d = await db;
    return d.query('goals', where: 'deleted = 0', orderBy: 'created_at DESC');
  }

  static Future<int> insertGoalOffline(Map<String, dynamic> goal) async {
    final d = await db;
    return d.insert('goals', {
      ...goal,
      'synced': 0,
      'deleted': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> updateGoalStatus(int id, String status) async {
    final d = await db;
    await d.update('goals', {'status': status, 'synced': 0},
        where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> markGoalDeleted(int id) async {
    final d = await db;
    await d.update('goals', {'deleted': 1, 'synced': 0},
        where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<Map<String, dynamic>>> getUnsyncedGoals() async {
    final d = await db;
    return d.query('goals', where: 'synced = 0');
  }

  // ── Library ──────────────────────────────────────────────
  static Future<void> saveLibrary(List<Map<String, dynamic>> items) async {
    final d = await db;
    final batch = d.batch();
    for (final item in items) {
      batch.insert('library', {
        'id': item['id'],
        'title': item['title'],
        'type': item['type'],
        'url': item['url'],
        'description': item['description'],
        'category': item['category'],
        'created_at': item['created_at'] ?? item['createdAt'] ?? DateTime.now().toIso8601String(),
        'synced': 1,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Map<String, dynamic>>> getLibrary() async {
    final d = await db;
    return d.query('library', orderBy: 'created_at DESC');
  }

  // ── Events ───────────────────────────────────────────────
  static Future<void> saveEvents(List<Map<String, dynamic>> events) async {
    final d = await db;
    final batch = d.batch();
    for (final e in events) {
      batch.insert('events', {
        'id': e['id'],
        'title': e['title'],
        'description': e['description'],
        'type': e['type'] ?? 'general',
        'start_date': e['start_date'] ?? e['startDate'],
        'end_date': e['end_date'] ?? e['endDate'],
        'conference_id': e['conference_id'] ?? e['conferenceId'],
        'created_by': e['created_by'] ?? e['createdBy'],
        'created_at': e['created_at'] ?? e['createdAt'] ?? DateTime.now().toIso8601String(),
        'synced': 1,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Map<String, dynamic>>> getEvents({int? month, int? year}) async {
    final d = await db;
    if (month != null && year != null) {
      final start = DateTime(year, month, 1).toIso8601String();
      final end = DateTime(year, month + 1, 0, 23, 59, 59).toIso8601String();
      return d.query('events',
          where: 'start_date >= ? AND start_date <= ?',
          whereArgs: [start, end],
          orderBy: 'start_date ASC');
    }
    return d.query('events', orderBy: 'start_date ASC');
  }

  // ── Conferences ──────────────────────────────────────────
  static Future<void> saveConferences(List<Map<String, dynamic>> confs) async {
    final d = await db;
    final batch = d.batch();
    for (final c in confs) {
      batch.insert('conferences', {
        'id': c['id'],
        'title': c['title'],
        'room_id': c['room_id'] ?? c['roomId'],
        'video_url': c['video_url'] ?? c['videoUrl'],
        'trainer_name': c['user']?['name'],
        'created_at': c['created_at'] ?? c['createdAt'] ?? DateTime.now().toIso8601String(),
        'synced': 1,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Map<String, dynamic>>> getConferences() async {
    final d = await db;
    return d.query('conferences', orderBy: 'created_at DESC');
  }

  // ── Dashboard Cache ──────────────────────────────────────
  static Future<void> saveDashboard(String key, String value) async {
    final d = await db;
    await d.insert('dashboard_cache', {
      'key': key,
      'value': value,
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<String?> getDashboard(String key) async {
    final d = await db;
    final rows = await d.query('dashboard_cache', where: 'key = ?', whereArgs: [key]);
    return rows.isNotEmpty ? rows.first['value'] as String? : null;
  }

  // ── Pending Sync ─────────────────────────────────────────
  static Future<void> addPendingSync({
    required String action,
    required String tableName,
    int? recordId,
    required Map<String, dynamic> data,
  }) async {
    final d = await db;
    await d.insert('pending_sync', {
      'action': action,
      'table_name': tableName,
      'record_id': recordId,
      'data': data.toString(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getPendingSync() async {
    final d = await db;
    return d.query('pending_sync', orderBy: 'created_at ASC');
  }

  static Future<void> removePendingSync(int id) async {
    final d = await db;
    await d.delete('pending_sync', where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> get pendingCount async {
    final d = await db;
    final result = await d.rawQuery('SELECT COUNT(*) as count FROM pending_sync');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ── Clear All ────────────────────────────────────────────
  static Future<void> clearAll() async {
    final d = await db;
    await d.delete('auth');
    await d.delete('goals');
    await d.delete('library');
    await d.delete('events');
    await d.delete('conferences');
    await d.delete('pending_sync');
    await d.delete('dashboard_cache');
  }
}
