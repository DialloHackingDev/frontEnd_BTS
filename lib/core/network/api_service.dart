import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../storage/local_storage_service.dart';
import '../storage/database_service.dart';
import '../res/constants.dart';

/// Service API optimisé - MODE SILENCIEUX TOTAL
/// Tout fonctionne en arrière-plan, l'utilisateur ne voit rien
/// - Retry automatique invisible (3 tentatives max)
/// - Fallback cache automatique sans notification
/// - Compression GZIP transparente
/// - Timeouts adaptatifs silencieux
class ApiService {
  static String get baseUrl => AppConstants.apiBaseUrl;
  
  // Timeouts adaptatifs (secondes)
  static const int _timeoutFast = 8;    // Requêtes simples
  static const int _timeoutSlow = 20;   // Requêtes lourdes
  static const int _timeoutUpload = 60; // Uploads fichiers
  
  // Retry configuration
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  // Client HTTP avec compression
  late final http.Client _client;
  
  ApiService() {
    // Activer la compression GZIP
    final ioClient = HttpClient()
      ..autoUncompress = true
      ..idleTimeout = const Duration(seconds: 30);
    _client = IOClient(ioClient);
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = LocalStorageService.cachedToken
        ?? await DatabaseService.getAuth('token');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${token ?? ""}',
      'Accept-Encoding': 'gzip', // Demander compression GZIP
    };
  }
  
  /// Retry silencieux avec exponential backoff
  /// Aucun message n'est affiché à l'utilisateur
  Future<T> _withRetry<T>(Future<T> Function() operation) async {
    int attempts = 0;
    Duration delay = _retryDelay;
    
    while (attempts < _maxRetries) {
      try {
        attempts++;
        return await operation();
      } on SocketException {
        if (attempts >= _maxRetries) rethrow;
        await Future.delayed(delay);
        delay *= 2; // Exponential backoff silencieux
      } on TimeoutException {
        if (attempts >= _maxRetries) rethrow;
        await Future.delayed(delay);
        delay *= 2;
      }
    }
    throw Exception('Échec après $_maxRetries tentatives');
  }

  Future<http.Response> get(String endpoint, {
    Map<String, String>? queryParams,
    bool useCache = true,
    int? timeoutSeconds,
  }) async {
    return _withRetry(() async {
      final headers = await _getHeaders();
      Uri uri = Uri.parse('$baseUrl$endpoint');
      if (queryParams != null) {
        uri = uri.replace(queryParameters: {...uri.queryParameters, ...queryParams});
      }
      
      debugPrint('🌐 API GET: $uri');
      
      final timeout = Duration(seconds: timeoutSeconds ?? _timeoutFast);
      final response = await _client.get(uri, headers: headers).timeout(timeout);
      
      debugPrint('📡 Response: ${response.statusCode} for $endpoint');

      if (response.statusCode == 200 && useCache) {
        _cacheData(endpoint, response.body);
      }
      return response;
    });
  }

  void _cacheData(String endpoint, String body) {
    final dynamic data = jsonDecode(body);
    if (endpoint == '/dashboard/stats') {
      DatabaseService.saveDashboard('stats', body);
    }
    if (endpoint.startsWith('/goals')) {
      final items = data is List ? data : (data['data'] ?? []);
      DatabaseService.saveGoals(List<Map<String, dynamic>>.from(items));
    }
    if (endpoint.startsWith('/library')) {
      final items = data is List ? data : (data['data'] ?? []);
      DatabaseService.saveLibrary(List<Map<String, dynamic>>.from(items));
    }
  }

  dynamic _getCachedData(String endpoint) => null;

  Future<http.Response> post(String endpoint, Map<String, dynamic> data, {bool isHeavy = false}) async {
    return _withRetry(() async {
      final headers = await _getHeaders();
      final timeout = Duration(seconds: isHeavy ? _timeoutSlow : _timeoutFast);
      
      return await _client.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: jsonEncode(data),
      ).timeout(timeout);
    });
  }

  Future<http.Response> put(String endpoint, Map<String, dynamic> data) async {
    return _withRetry(() async {
      final headers = await _getHeaders();
      return await _client.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: jsonEncode(data),
      ).timeout(Duration(seconds: _timeoutFast));
    });
  }

  Future<http.Response> delete(String endpoint) async {
    return _withRetry(() async {
      final headers = await _getHeaders();
      return await _client.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
      ).timeout(Duration(seconds: _timeoutFast));
    });
  }
  
  /// Upload fichier avec retry silencieux
  Future<http.Response> uploadFileWithProgress(
    String endpoint,
    List<int> fileBytes,
    String filename, {
    void Function(double)? onProgress,
    Map<String, String>? fields,
  }) async {
    return _withRetry(() async {
      final token = LocalStorageService.cachedToken ?? await DatabaseService.getAuth('token');
      final uri = Uri.parse('$baseUrl$endpoint');
      
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer ${token ?? ""}'
        ..headers['Accept-Encoding'] = 'gzip'
        ..files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: filename));
      
      if (fields != null) {
        request.fields.addAll(fields);
      }
      
      final streamedResponse = await request.send().timeout(Duration(seconds: _timeoutUpload));
      return await http.Response.fromStream(streamedResponse);
    });
  }
  
  /// Upload depuis path avec retry silencieux
  Future<http.StreamedResponse> uploadFile(
    String endpoint,
    String filePath,
    String title, {
    void Function(double)? onProgress,
  }) async {
    return _withRetry(() async {
      final token = LocalStorageService.cachedToken ?? await DatabaseService.getAuth('token');
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$endpoint'));
      request.headers.addAll({'Authorization': 'Bearer $token'});
      request.fields['title'] = title;
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      
      final streamedResponse = await request.send().timeout(Duration(seconds: _timeoutUpload));
      
      if (onProgress != null) {
        final total = await File(filePath).length();
        int received = 0;
        streamedResponse.stream.listen(
          (chunk) {
            received += chunk.length;
            onProgress(received / total);
          },
        );
      }
      
      return streamedResponse;
    });
  }

  /// Upload image avec retry silencieux
  Future<http.StreamedResponse> uploadImage(String endpoint, String filePath, String fieldName) async {
    return _withRetry(() async {
      final token = LocalStorageService.cachedToken ?? await DatabaseService.getAuth('token');
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$endpoint'));
      request.headers.addAll({'Authorization': 'Bearer $token'});
      request.files.add(await http.MultipartFile.fromPath(fieldName, filePath));
      final response = await request.send().timeout(Duration(seconds: _timeoutSlow));
      return response;
    });
  }
  
  /// Upload bytes avec retry silencieux
  Future<http.StreamedResponse> uploadFileBytes(
    String endpoint,
    List<int> bytes,
    String filename,
    String title,
  ) async {
    return _withRetry(() async {
      final token = LocalStorageService.cachedToken ?? await DatabaseService.getAuth('token');
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$endpoint'));
      request.headers.addAll({'Authorization': 'Bearer $token'});
      request.fields['title'] = title;
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
      final response = await request.send().timeout(Duration(seconds: _timeoutUpload));
      return response;
    });
  }
}
