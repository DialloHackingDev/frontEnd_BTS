import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service de gestion de la connectivité - MODE SILENCIEUX
/// Gère tout en arrière-plan sans afficher d'UI à l'utilisateur
/// - Retry automatique silencieux
/// - Fallback cache transparent
/// - Adaptation qualité auto
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  
  List<ConnectivityResult> _currentStatus = [ConnectivityResult.none];
  bool _isSlowConnection = false;
  
  /// Callbacks pour notifier les changements
  final List<void Function(List<ConnectivityResult>)> _listeners = [];

  /// Initialise le service (silencieux)
  Future<void> initialize() async {
    try {
      _currentStatus = await _connectivity.checkConnectivity();
      _evaluateConnectionSpeed();
      _log('Statut initial: $connectionLabel');
      
      _subscription = _connectivity.onConnectivityChanged.listen((results) {
        _currentStatus = results;
        _evaluateConnectionSpeed();
        _log('Changement connexion: $connectionLabel');
        _notifyListeners();
      });
    } catch (e) {
      _log('Erreur init: $e');
    }
  }

  /// Dispose le service
  void dispose() {
    _subscription?.cancel();
  }

  /// Évalue si la connexion est lente
  void _evaluateConnectionSpeed() {
    _isSlowConnection = _currentStatus.contains(ConnectivityResult.mobile) ||
                        _currentStatus.contains(ConnectivityResult.bluetooth);
  }

  /// Notifie tous les listeners (interne uniquement)
  void _notifyListeners() {
    for (final listener in _listeners) {
      listener(_currentStatus);
    }
  }

  /// Ajoute un listener (usage interne uniquement)
  void addListener(void Function(List<ConnectivityResult>) listener) {
    _listeners.add(listener);
  }

  /// Retire un listener
  void removeListener(void Function(List<ConnectivityResult>) listener) {
    _listeners.remove(listener);
  }
  
  /// Log silencieux (debug uniquement)
  void _log(String message) {
    // En production: ne rien afficher
    // debugPrint('[Connectivity] $message');
  }

  /// Vérifie si on est connecté
  bool get isConnected => !_currentStatus.contains(ConnectivityResult.none);

  /// Vérifie si la connexion est rapide (WiFi)
  bool get isFastConnection => _currentStatus.contains(ConnectivityResult.wifi) ||
                               _currentStatus.contains(ConnectivityResult.ethernet);

  /// Vérifie si la connexion est lente (Mobile/3G/4G)
  bool get isSlowConnection => _isSlowConnection;

  /// Types de connexion actuels
  List<ConnectivityResult> get currentStatus => _currentStatus;

  /// String représentatif de la connexion
  String get connectionLabel {
    if (_currentStatus.isEmpty) return 'Hors ligne';
    
    final labels = _currentStatus.map((status) {
      switch (status) {
        case ConnectivityResult.wifi:
          return 'WiFi';
        case ConnectivityResult.mobile:
          return 'Mobile';
        case ConnectivityResult.ethernet:
          return 'Ethernet';
        case ConnectivityResult.bluetooth:
          return 'Bluetooth';
        case ConnectivityResult.vpn:
          return 'VPN';
        default:
          return 'Hors ligne';
      }
    }).toList();
    
    return labels.join(' + ');
  }

  /// Recommandation pour le type de média à charger
  MediaQuality get recommendedQuality {
    if (isFastConnection) return MediaQuality.high;
    if (isSlowConnection) return MediaQuality.low;
    return MediaQuality.none; // Hors ligne
  }
}

/// Qualité des médias recommandée
enum MediaQuality {
  high,  // WiFi - Vidéo HD, images haute qualité
  low,   // Mobile - Vidéo basse qualité, images compressées
  none,  // Hors ligne - Pas de streaming
}
