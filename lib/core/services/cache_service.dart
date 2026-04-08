import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Service de cache intelligent pour les fichiers média
/// Gère le téléchargement, le stockage et la récupération des fichiers PDF/Audio
class CacheService {
  static Database? _db;
  static final Dio _dio = Dio();
  
  /// Limite de cache totale (100 MB)
  static const int maxCacheSizeMB = 100;
  
  /// Durée de validité du cache (7 jours)
  static const int cacheValidityDays = 7;

  /// Initialise la base de données de cache
  static Future<Database> get _database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'bts_cache.db');
    
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cached_files (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            url TEXT UNIQUE NOT NULL,
            local_path TEXT NOT NULL,
            file_type TEXT NOT NULL,
            file_size INTEGER DEFAULT 0,
            created_at INTEGER NOT NULL,
            last_accessed INTEGER NOT NULL,
            access_count INTEGER DEFAULT 1
          )
        ''');
        
        await db.execute('''
          CREATE INDEX idx_url ON cached_files(url)
        ''');
        await db.execute('''
          CREATE INDEX idx_last_accessed ON cached_files(last_accessed)
        ''');
      },
    );
  }

  /// Récupère un fichier du cache s'il existe et est valide
  static Future<String?> getCachedFile(String url) async {
    try {
      final db = await _database;
      final result = await db.query(
        'cached_files',
        where: 'url = ?',
        whereArgs: [url],
        limit: 1,
      );

      if (result.isEmpty) return null;

      final file = result.first;
      final localPath = file['local_path'] as String;
      final createdAt = DateTime.fromMillisecondsSinceEpoch(file['created_at'] as int);
      
      // Vérifier si le fichier existe toujours physiquement
      final fileObj = File(localPath);
      if (!await fileObj.exists()) {
        await _removeFromCache(url);
        return null;
      }

      // Vérifier la validité (7 jours)
      final now = DateTime.now();
      if (now.difference(createdAt).inDays > cacheValidityDays) {
        await _removeFromCache(url);
        return null;
      }

      // Mettre à jour les stats d'accès
      await db.update(
        'cached_files',
        {
          'last_accessed': DateTime.now().millisecondsSinceEpoch,
          'access_count': (file['access_count'] as int) + 1,
        },
        where: 'url = ?',
        whereArgs: [url],
      );

      return localPath;
    } catch (e) {
      print('Erreur cache get: $e');
      return null;
    }
  }

  /// Télécharge et met en cache un fichier avec suivi de progression
  static Future<String> downloadAndCache(
    String url, {
    required String fileType,
    void Function(double progress)? onProgress,
  }) async {
    try {
      // Vérifier d'abord le cache
      final cached = await getCachedFile(url);
      if (cached != null) {
        print('Cache hit: $url');
        return cached;
      }

      final dir = await _getCacheDirectory();
      final fileName = 'bts_${fileType}_${DateTime.now().millisecondsSinceEpoch}.${_getExtension(fileType)}';
      final filePath = '${dir.path}/$fileName';

      print('Téléchargement: $url');
      
      // Télécharger avec suivi de progression
      await _dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0 && onProgress != null) {
            onProgress(received / total);
          }
        },
      );

      // Obtenir la taille du fichier
      final file = File(filePath);
      final fileSize = await file.length();

      // Sauvegarder dans la base de données
      final db = await _database;
      await db.insert('cached_files', {
        'url': url,
        'local_path': filePath,
        'file_type': fileType,
        'file_size': fileSize,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'last_accessed': DateTime.now().millisecondsSinceEpoch,
        'access_count': 1,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Nettoyer le cache si nécessaire
      await _cleanupIfNeeded();

      return filePath;
    } catch (e) {
      print('Erreur téléchargement cache: $e');
      throw e;
    }
  }

  /// Supprime un fichier du cache
  static Future<void> _removeFromCache(String url) async {
    try {
      final db = await _database;
      final result = await db.query(
        'cached_files',
        where: 'url = ?',
        whereArgs: [url],
      );

      if (result.isNotEmpty) {
        final path = result.first['local_path'] as String;
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
        await db.delete('cached_files', where: 'url = ?', whereArgs: [url]);
      }
    } catch (e) {
      print('Erreur suppression cache: $e');
    }
  }

  /// Nettoie les fichiers les moins utilisés si le cache dépasse la limite
  static Future<void> _cleanupIfNeeded() async {
    try {
      final db = await _database;
      
      // Calculer la taille totale
      final result = await db.rawQuery('SELECT SUM(file_size) as total FROM cached_files');
      final totalSize = (result.first['total'] as int?) ?? 0;
      
      if (totalSize > maxCacheSizeMB * 1024 * 1024) {
        print('Nettoyage cache...');
        
        // Récupérer les fichiers les moins utilisés
        final oldFiles = await db.query(
          'cached_files',
          orderBy: 'access_count ASC, last_accessed ASC',
          limit: 10,
        );

        for (final file in oldFiles) {
          await _removeFromCache(file['url'] as String);
        }
      }
    } catch (e) {
      print('Erreur cleanup cache: $e');
    }
  }

  /// Récupère les statistiques du cache
  static Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final db = await _database;
      
      final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM cached_files')
      ) ?? 0;
      
      final size = Sqflite.firstIntValue(
        await db.rawQuery('SELECT SUM(file_size) FROM cached_files')
      ) ?? 0;

      final pdfCount = Sqflite.firstIntValue(
        await db.rawQuery("SELECT COUNT(*) FROM cached_files WHERE file_type = 'pdf'")
      ) ?? 0;

      final audioCount = Sqflite.firstIntValue(
        await db.rawQuery("SELECT COUNT(*) FROM cached_files WHERE file_type = 'audio'")
      ) ?? 0;

      return {
        'totalFiles': count,
        'totalSizeMB': (size / (1024 * 1024)).toStringAsFixed(2),
        'pdfCount': pdfCount,
        'audioCount': audioCount,
        'maxSizeMB': maxCacheSizeMB,
      };
    } catch (e) {
      return {
        'totalFiles': 0,
        'totalSizeMB': '0.00',
        'pdfCount': 0,
        'audioCount': 0,
        'maxSizeMB': maxCacheSizeMB,
      };
    }
  }

  /// Vide complètement le cache
  static Future<void> clearCache() async {
    try {
      final db = await _database;
      final files = await db.query('cached_files');
      
      for (final file in files) {
        final path = file['local_path'] as String;
        final fileObj = File(path);
        if (await fileObj.exists()) {
          await fileObj.delete();
        }
      }
      
      await db.delete('cached_files');
    } catch (e) {
      print('Erreur vidage cache: $e');
    }
  }

  /// Supprime uniquement les fichiers expirés
  static Future<int> clearExpired() async {
    try {
      final db = await _database;
      final threshold = DateTime.now().subtract(Duration(days: cacheValidityDays));
      
      final expired = await db.query(
        'cached_files',
        where: 'created_at < ?',
        whereArgs: [threshold.millisecondsSinceEpoch],
      );

      for (final file in expired) {
        await _removeFromCache(file['url'] as String);
      }

      return expired.length;
    } catch (e) {
      print('Erreur nettoyage expirés: $e');
      return 0;
    }
  }

  /// Retourne le répertoire de cache
  static Future<Directory> _getCacheDirectory() async {
    final dir = await getTemporaryDirectory();
    final cacheDir = Directory('${dir.path}/bts_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// Retourne l'extension de fichier appropriée
  static String _getExtension(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return 'pdf';
      case 'audio':
        return 'mp3';
      case 'video':
        return 'mp4';
      default:
        return 'bin';
    }
  }

  /// Précharge un fichier en arrière-plan (sans bloquer l'UI)
  static Future<void> preload(String url, String fileType) async {
    try {
      final cached = await getCachedFile(url);
      if (cached == null) {
        // Téléchargement silencieux en arrière-plan
        await downloadAndCache(url, fileType: fileType).catchError((e) {
          print('Préchargement échoué: $e');
          return '';
        });
      }
    } catch (e) {
      print('Erreur préchargement: $e');
    }
  }
}
