import 'dart:convert';
import 'package:http/http.dart' as http;
import '../storage/local_storage_service.dart';
import '../res/constants.dart';

class ApiService {
  static String get baseUrl => AppConstants.apiBaseUrl;
  final LocalStorageService _storage = LocalStorageService();

  Future<Map<String, String>> _getHeaders() async {
    final token = _storage.getToken();
    
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> get(String endpoint, {Map<String, String>? queryParams}) async {
    try {
      final headers = await _getHeaders();
      Uri uri = Uri.parse('$baseUrl$endpoint');
      if (queryParams != null) {
        uri = uri.replace(queryParameters: {...uri.queryParameters, ...queryParams});
      }
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        _cacheData(endpoint, response.body);
      }
      return response;
    } catch (e) {
      final cachedData = _getCachedData(endpoint);
      if (cachedData != null) {
        return http.Response(jsonEncode(cachedData), 200);
      }
      rethrow;
    }
  }

  void _cacheData(String endpoint, String body) {
    final dynamic data = jsonDecode(body);
    if (endpoint == '/dashboard/stats') _storage.saveDashboard(data);
    // Pour les endpoints paginés, on cache uniquement la page 1
    if (endpoint == '/goals') _storage.saveGoals(data is List ? data : (data['data'] ?? []));
    if (endpoint == '/library') _storage.saveLibrary(data is List ? data : (data['data'] ?? []));
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

  Future<http.StreamedResponse> uploadFile(String endpoint, String filePath, String title) async {
    final token = _storage.getToken();
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$endpoint'));
    request.headers.addAll({'Authorization': 'Bearer $token'});
    request.fields['title'] = title;
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    return request.send();
  }

  Future<http.StreamedResponse> uploadImage(String endpoint, String filePath, String fieldName) async {
    final token = _storage.getToken();
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$endpoint'));
    request.headers.addAll({'Authorization': 'Bearer $token'});
    request.files.add(await http.MultipartFile.fromPath(fieldName, filePath));
    final response = await request.send().timeout(const Duration(seconds: 30));
    return response;
  }
}
