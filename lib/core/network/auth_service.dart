import 'dart:convert';
import 'package:http/http.dart' as http;
import '../storage/local_storage_service.dart';

class AuthService {
  final String _baseUrl = 'http://localhost:3000/auth';
  final LocalStorageService _storage = LocalStorageService();

  // Login
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        await _storage.saveToken(data['token']);
        await _storage.saveUser(data['user']);
        return {'success': true};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Autentication failed'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Register
  Future<Map<String, dynamic>> register(String email, String password, String name) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password, 'name': name}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        await _storage.saveToken(data['token']);
        await _storage.saveUser(data['user']);
        return {'success': true};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Registration failed'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Logout
  Future<void> logout() async {
    await _storage.clearAll();
  }

  // Get current session
  bool isLoggedIn() {
    return _storage.getToken() != null;
  }

  String? get token => _storage.getToken();
  dynamic get user => _storage.getUser();
}
