import 'dart:convert';
import 'package:http/http.dart' as http;
import '../storage/local_storage_service.dart';
import '../storage/database_service.dart';
import '../res/constants.dart';

class ApiService {
  static String get baseUrl => AppConstants.apiBaseUrl;

  Future<Map<String, String>> _getHeaders() async {
    final token = LocalStorageService.cachedToken
        ?? await DatabaseService.getAuth('token');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${token ?? ""}',
    };
  }

  Future<http.Response> get(String endpoint, {Map<String, String>? queryParams}) async {
    try {
      final headers = await _getHeaders();
      Uri uri = Uri.parse('$baseUrl$endpoint');
      if (queryParams != null) {
        uri = uri.replace(queryParameters: {...uri.queryParameters, ...queryParams});
      }
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));

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
    final token = LocalStorageService.cachedToken ?? await DatabaseService.getAuth('token');
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$endpoint'));
    request.headers.addAll({'Authorization': 'Bearer $token'});
    request.fields['title'] = title;
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    final response = await request.send().timeout(const Duration(seconds: 120));
    return response;
  }

  Future<http.StreamedResponse> uploadFileBytes(
    String endpoint,
    List<int> bytes,
    String filename,
    String title,
  ) async {
    final token = LocalStorageService.cachedToken ?? await DatabaseService.getAuth('token');
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$endpoint'));
    request.headers.addAll({'Authorization': 'Bearer $token'});
    request.fields['title'] = title;
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final response = await request.send().timeout(const Duration(seconds: 120));
    return response;
  }

  Future<http.StreamedResponse> uploadImage(String endpoint, String filePath, String fieldName) async {
    final token = LocalStorageService.cachedToken ?? await DatabaseService.getAuth('token');
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$endpoint'));
    request.headers.addAll({'Authorization': 'Bearer $token'});
    request.files.add(await http.MultipartFile.fromPath(fieldName, filePath));
    final response = await request.send().timeout(const Duration(seconds: 30));
    return response;
  }
}
