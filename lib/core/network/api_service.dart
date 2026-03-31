import 'dart:convert';
import 'package:http/http.dart' as http;
import '../storage/local_storage_service.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:3000';
  final LocalStorageService _storage = LocalStorageService();

  Future<Map<String, String>> _getHeaders() async {
    final token = _storage.getToken();
    
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> get(String endpoint) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('$baseUrl$endpoint'), headers: headers).timeout(const Duration(seconds: 5));

      // Sauvegarde automatique dans le cache si succès
      if (response.statusCode == 200) {
        _cacheData(endpoint, response.body);
      }
      
      return response;
    } catch (e) {
      // Si hors-ligne ou erreur réseau, on tente de récupérer le cache
      final cachedData = _getCachedData(endpoint);
      if (cachedData != null) {
        return http.Response(jsonEncode(cachedData), 200);
      }
      rethrow; // Si pas de cache non plus, on laisse l'erreur remonter
    }
  }

  void _cacheData(String endpoint, String body) {
    final dynamic data = jsonDecode(body);
    if (endpoint == '/dashboard/stats') _storage.saveDashboard(data);
    if (endpoint == '/goals') _storage.saveGoals(data);
    if (endpoint == '/library') _storage.saveLibrary(data);
  }

  dynamic _getCachedData(String endpoint) {
    if (endpoint == '/dashboard/stats') return _storage.getDashboard();
    if (endpoint == '/goals') return _storage.getGoals();
    if (endpoint == '/library') return _storage.getLibrary();
    return null;
  }

  Future<http.Response> post(String endpoint, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    return http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
      body: jsonEncode(data),
    );
  }

  Future<http.Response> put(String endpoint, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    return http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
      body: jsonEncode(data),
    );
  }

  Future<http.Response> delete(String endpoint) async {
    final headers = await _getHeaders();
    return http.delete(Uri.parse('$baseUrl$endpoint'), headers: headers);
  }
}
