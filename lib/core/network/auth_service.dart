import 'dart:convert';
import 'package:http/http.dart' as http;
import '../storage/local_storage_service.dart';
import '../storage/database_service.dart';
import '../res/constants.dart';

class AuthService {
  String get _baseUrl => '${AppConstants.apiBaseUrl}/auth';

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        await DatabaseService.saveAuth('token', data['token']);
        await DatabaseService.saveAuth('user', jsonEncode(data['user']));
        LocalStorageService.cachedToken = data['token'];
        LocalStorageService.cachedUser = data['user'];
        return {'success': true};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Email ou mot de passe incorrect'};
      }
    } catch (e) {
      final msg = e.toString().contains('TimeoutException')
          ? 'Connexion impossible. Vérifiez votre réseau.'
          : 'Erreur de connexion: ${e.toString().replaceAll('Exception: ', '')}';
      return {'success': false, 'error': msg};
    }
  }

  Future<Map<String, dynamic>> register(String email, String password, String name) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password, 'name': name}),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        await DatabaseService.saveAuth('token', data['token']);
        await DatabaseService.saveAuth('user', jsonEncode(data['user']));
        LocalStorageService.cachedToken = data['token'];
        LocalStorageService.cachedUser = data['user'];
        return {'success': true};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Inscription échouée'};
      }
    } catch (e) {
      final msg = e.toString().contains('TimeoutException')
          ? 'Connexion impossible. Vérifiez votre réseau.'
          : 'Erreur: ${e.toString().replaceAll('Exception: ', '')}';
      return {'success': false, 'error': msg};
    }
  }

  Future<void> logout() async {
    LocalStorageService.cachedToken = null;
    LocalStorageService.cachedUser = null;
    await DatabaseService.clearAll();
  }

  bool isLoggedIn() => LocalStorageService.cachedToken != null;
  String? get token => LocalStorageService.cachedToken;
  dynamic get user => LocalStorageService.cachedUser;
}
