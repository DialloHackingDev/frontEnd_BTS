import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/res/styles.dart';
import '../../../core/network/api_service.dart';

class JitsiRoomScreen extends StatefulWidget {
  final String roomId;
  final String title;
  final int? conferenceId;

  const JitsiRoomScreen({
    super.key,
    required this.roomId,
    required this.title,
    this.conferenceId,
  });

  @override
  State<JitsiRoomScreen> createState() => _JitsiRoomScreenState();
}

class _JitsiRoomScreenState extends State<JitsiRoomScreen> {
  static const String _appId = 'c09cfdf14ad74aca86c7688fa9d251b8';

  RtcEngine? _engine;
  bool _isInitializing = true;
  bool _localVideoEnabled = true;
  bool _localAudioEnabled = true;
  bool _isRecording = false;
  String? _error;
  final List<int> _remoteUids = [];
  int? _conferenceId; // ID de la conférence pour l'enregistrement
  
  // Timer de l'appel
  Timer? _callTimer;
  int _callDuration = 0; // en secondes
  
  final TextEditingController _chatController = TextEditingController();
  final List<Map<String, dynamic>> _chatMessages = [];
  
  // Réactions emoji temporaires
  final List<Map<String, dynamic>> _floatingReactions = [];
  
  // Partage d'écran
  bool _isScreenSharing = false;
  int? _screenShareUid; // UID du participant qui partage (null = personne)
  
  // Lever de main
  bool _isHandRaised = false;
  final Set<int> _raisedHands = {}; // Set des UIDs qui ont levé la main
  
  // Chat stream ID
  int? _chatStreamId;
  
  @override
  void dispose() {
    _callTimer?.cancel();
    _chatController.dispose();
    _stopRecording();
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }
  
  /// Démarre le timer de l'appel
  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDuration++;
        });
      }
    });
  }
  
  /// Formate la durée en HH:MM:SS
  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
  
  /// Affiche la boîte de dialogue pour quitter
  Future<void> _showLeaveDialog() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.navy,
        title: const Text('Quitter la réunion ?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Vous allez quitter la salle de conférence.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ANNULER', style: TextStyle(color: AppColors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('QUITTER'),
          ),
        ],
      ),
    );
    
    if (shouldLeave == true) {
      _leaveChannel();
    }
  }
  
  /// Construit un bouton d'icône circulaire
  Widget _buildIconButton(IconData icon, {required VoidCallback onTap, Color? bgColor, Color? iconColor, double size = 24}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: bgColor ?? Colors.black26,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor ?? Colors.white, size: size),
      ),
    );
  }
  
  /// Construit un bouton de contrôle avec label
  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    required String label,
    bool isActive = true,
    Color? activeColor,
    Color? inactiveColor = Colors.redAccent,
  }) {
    final bgColor = isActive 
        ? (activeColor ?? Colors.black26)
        : (inactiveColor ?? Colors.redAccent);
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon, 
              color: isActive ? Colors.white : Colors.white, 
              size: 26,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _initConferenceAndRecording();
  }

  /// Initialise la conférence et démarre l'enregistrement automatique
  Future<void> _initConferenceAndRecording() async {
    // Utiliser le conferenceId du widget s'il existe
    if (widget.conferenceId != null) {
      _conferenceId = widget.conferenceId;
    }
    await _initAgora();
    if (_error == null && mounted) {
      await _startRecording();
    }
  }

  /// Démarre l'enregistrement automatique
  Future<void> _startRecording() async {
    try {
      // Si on a déjà un conferenceId, utiliser celui-ci
      if (_conferenceId == null) {
        // Créer une nouvelle conférence
        final response = await ApiService().post('/conferences', {
          'title': widget.title,
        });

        if (response.statusCode == 201) {
          final data = jsonDecode(response.body);
          _conferenceId = data['id'];
        } else {
          debugPrint('⚠️ Impossible de créer la conférence: ${response.statusCode}');
          return;
        }
      }

      // Démarrer l'enregistrement Agora
      final recordingRes = await ApiService().post('/agora/recording/start', {
        'conferenceId': _conferenceId,
        'channelName': _channelName,
      });

      if (recordingRes.statusCode == 200) {
        setState(() => _isRecording = true);
        debugPrint('🎥 Enregistrement démarré pour conférence $_conferenceId');
      }
    } catch (e) {
      debugPrint('⚠️ Impossible de démarrer l\'enregistrement: $e');
      // Ne pas bloquer la conférence si l'enregistrement échoue
    }
  }

  // Agora accepte lettres, chiffres, tirets, underscores — max 64 chars
  String get _channelName {
    final clean = widget.roomId.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '');
    return clean.length > 64 ? clean.substring(0, 64) : clean;
  }

  Future<void> _initAgora() async {
    setState(() { _isInitializing = true; _error = null; });

    if (!Platform.isAndroid && !Platform.isIOS) {
      setState(() {
        _error = 'La vidéoconférence n\'est disponible que sur Android et iOS.';
        _isInitializing = false;
      });
      return;
    }

    await [Permission.camera, Permission.microphone].request();

    try {
      // Récupérer le token depuis le backend avec le VRAI channelName
      String token = '';
      try {
        final response = await ApiService().get(
          '/agora/token',
          queryParams: {'channelName': _channelName},
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          token = data['token'] ?? '';
          debugPrint('Token Agora récupéré: ${token.substring(0, 20)}...');
          debugPrint('ChannelName: $_channelName');
        } else {
          debugPrint('Erreur token: ${response.statusCode} ${response.body}');
        }
      } catch (e) {
        debugPrint('Impossible de récupérer le token: $e');
      }

      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(appId: _appId));
      await _engine!.enableVideo();
      await _engine!.enableAudio();
      await _engine!.startPreview();

      _engine!.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) async {
          debugPrint('Agora: canal rejoint avec succès');
          _startCallTimer(); // Démarrer le timer de l'appel
          
          // Créer le data stream pour le chat (une seule fois)
          if (_chatStreamId == null) {
            try {
              _chatStreamId = await _engine?.createDataStream(
                const DataStreamConfig(syncWithAudio: false, ordered: true),
              );
              debugPrint('✅ Chat stream créé: $_chatStreamId');
            } catch (e) {
              debugPrint('❌ Erreur création stream: $e');
            }
          }
          
          if (mounted) setState(() => _isInitializing = false);
        },
        onUserJoined: (connection, uid, elapsed) {
          debugPrint('Agora: utilisateur $uid a rejoint');
          if (mounted) setState(() => _remoteUids.add(uid));
        },
        onUserOffline: (connection, uid, reason) {
          if (mounted) setState(() => _remoteUids.remove(uid));
          // Retirer aussi des mains levées si l'utilisateur part
          _raisedHands.remove(uid);
        },
        onError: (err, msg) {
          debugPrint('Agora error: $err - $msg');
          if (mounted) setState(() { _error = 'Erreur ($err): $msg'; _isInitializing = false; });
        },
        onConnectionStateChanged: (connection, state, reason) {
          debugPrint('Agora connection state: $state reason: $reason');
          if (state == ConnectionStateType.connectionStateConnected && mounted) {
            setState(() => _isInitializing = false);
          }
        },
        onRemoteVideoStateChanged: (connection, remoteUid, state, reason, elapsed) {
          debugPrint('Agora video state: uid=$remoteUid state=$state');
          // Détecter le partage d'écran (state 2 = RemoteVideoStateStarting)
          if (state == RemoteVideoState.remoteVideoStateStarting) {
            // Vérifier si c'est un partage d'écran (type de flux)
            setState(() => _screenShareUid = remoteUid);
          } else if (state == RemoteVideoState.remoteVideoStateStopped) {
            if (_screenShareUid == remoteUid) {
              setState(() => _screenShareUid = null);
            }
          }
        },
        onStreamMessage: (connection, remoteUid, streamId, data, length, sentTs) {
          // Recevoir un message de chat
          final message = String.fromCharCodes(data);
          debugPrint('💬 Message reçu de $remoteUid: $message');
          
          if (mounted) {
            setState(() {
              _chatMessages.add({
                'sender': remoteUid.toString(),
                'message': message,
                'isMe': false,
                'timestamp': DateTime.now(),
              });
            });
          }
        },
      ));

      // Enregistrer le handler AVANT de rejoindre
      await _engine!.joinChannel(
        token: token,
        channelId: _channelName,
        uid: 0,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );

      // Timeout de sécurité : si onJoinChannelSuccess ne se déclenche pas
      Future.delayed(const Duration(seconds: 8), () {
        if (mounted && _isInitializing) {
          setState(() => _isInitializing = false);
        }
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isInitializing = false; });
    }
  }

  Future<void> _toggleVideo() async {
    setState(() => _localVideoEnabled = !_localVideoEnabled);
    await _engine?.muteLocalVideoStream(!_localVideoEnabled);
  }

  Future<void> _toggleAudio() async {
    setState(() => _localAudioEnabled = !_localAudioEnabled);
    await _engine?.muteLocalAudioStream(!_localAudioEnabled);
  }

  /// ─── PARTAGE D'ÉCRAN ───
  Future<void> _toggleScreenSharing() async {
    if (_isScreenSharing) {
      // Arrêter le partage d'écran
      await _stopScreenSharing();
    } else {
      // Démarrer le partage d'écran
      await _startScreenSharing();
    }
  }

  /// Démarre le partage d'écran
  Future<void> _startScreenSharing() async {
    try {
      if (Platform.isAndroid) {
        // Sur Android
        await _engine?.startScreenCapture(
          const ScreenCaptureParameters2(
            captureAudio: true,
            captureVideo: true,
          ),
        );
        
        // Publier le flux de partage d'écran
        await _engine?.updateChannelMediaOptions(
          const ChannelMediaOptions(
            publishScreenTrack: true,
            publishCameraTrack: false,
          ),
        );
        
        setState(() {
          _isScreenSharing = true;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📺 Partage d\'écran démarré'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else if (Platform.isIOS) {
        _showError('Le partage d\'écran nécessite iOS 11+ avec ReplayKit');
      }
    } catch (e) {
      debugPrint('❌ Erreur partage d\'écran: $e');
      _showError('Impossible de démarrer le partage d\'écran');
    }
  }

  /// Arrête le partage d'écran
  Future<void> _stopScreenSharing() async {
    try {
      await _engine?.stopScreenCapture();
      
      // Republier la caméra
      await _engine?.updateChannelMediaOptions(
        const ChannelMediaOptions(
          publishScreenTrack: false,
          publishCameraTrack: true,
        ),
      );
      
      setState(() {
        _isScreenSharing = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Partage d\'écran arrêté'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('❌ Erreur arrêt partage: $e');
    }
  }

  /// ─── LEVER DE MAIN ───
  Future<void> _toggleHandRaise() async {
    setState(() => _isHandRaised = !_isHandRaised);
    
    // TODO: Envoyer aux autres participants via le canal de données Agora
    // Pour l'instant, simulé localement
    
    if (_isHandRaised) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✋ Main levée'),
            backgroundColor: AppColors.gold,
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  /// ─── LEVER DE MAIN POUR AUTRES ───
  void _onRemoteHandRaised(int uid, bool isRaised) {
    setState(() {
      if (isRaised) {
        _raisedHands.add(uid);
      } else {
        _raisedHands.remove(uid);
      }
    });
  }

  Future<void> _leaveChannel() async {
    // Arrêter l'enregistrement avant de quitter
    await _stopRecording();
    await _engine?.leaveChannel();
    if (mounted) Navigator.pop(context);
  }

  /// Arrête l'enregistrement automatique
  Future<void> _stopRecording() async {
    if (_conferenceId != null && _isRecording) {
      try {
        final response = await ApiService().post('/agora/recording/stop', {
          'conferenceId': _conferenceId,
        });

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          debugPrint('✅ Enregistrement arrêté. Vidéo: ${data['videoUrl']}');
          setState(() => _isRecording = false);
        }
      } catch (e) {
        debugPrint('⚠️ Erreur arrêt enregistrement: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _isInitializing
            ? _buildLoading()
            : _error != null
                ? _buildError()
                : _buildConference(),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.gold),
          const SizedBox(height: 20),
          Text(
            'Connexion à "${widget.title}"...',
            style: const TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text('Initialisation caméra et micro...',
              style: TextStyle(color: AppColors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 60),
            const SizedBox(height: 16),
            const Text('Impossible de rejoindre la salle.',
                style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_error ?? '', style: const TextStyle(color: AppColors.grey, fontSize: 12), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _initAgora,
              icon: const Icon(Icons.refresh_rounded, color: AppColors.navy),
              label: const Text('RÉESSAYER', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold,
                  minimumSize: const Size(200, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: () => Navigator.pop(context),
                child: const Text('RETOUR', style: TextStyle(color: AppColors.grey))),
          ],
        ),
      ),
    );
  }

  /// Build the conference UI - Google Meet style
  Widget _buildConference() {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: Column(
          children: [
            // Header - Style Google Meet
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Bouton retour (flèche)
                  GestureDetector(
                    onTap: _showLeaveDialog,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: AppColors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Texte "Vous"
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Vous',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Icône volume
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.volume_up,
                        color: AppColors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Zone vidéo principale (ou message si seul)
            Expanded(
              child: _remoteUids.isEmpty
                  ? _buildWaitingView()
                  : Stack(
                      children: [
                        // Vidéo distante (plein écran)
                        AgoraVideoView(
                          controller: VideoViewController.remote(
                            rtcEngine: _engine!,
                            canvas: VideoCanvas(uid: _remoteUids.first),
                            connection: RtcConnection(channelId: _channelName),
                          ),
                        ),
                        // Vidéo locale (coin supérieur droit)
                        Positioned(
                          top: 16,
                          right: 16,
                          child: Container(
                            width: 120,
                            height: 160,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.gold, width: 2),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: _localVideoEnabled
                                  ? AgoraVideoView(
                                      controller: VideoViewController(
                                        rtcEngine: _engine!,
                                        canvas: const VideoCanvas(uid: 0),
                                      ),
                                    )
                                  : Container(
                                      color: AppColors.darkBlue,
                                      child: const Center(
                                        child: Icon(
                                          Icons.videocam_off_rounded,
                                          color: AppColors.grey,
                                          size: 40,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),

            // Barre de contrôles en bas - Style Google Meet
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Micro (rose/rouge quand coupé)
                    _buildMeetControlButton(
                      icon: _localAudioEnabled ? Icons.mic : Icons.mic_off,
                      onTap: _toggleAudio,
                      isActive: _localAudioEnabled,
                      activeColor: Colors.white.withOpacity(0.2),
                      inactiveColor: const Color(0xFFEF5350), // Rose/rouge
                    ),
                    // Caméra (gris foncé)
                    _buildMeetControlButton(
                      icon: _localVideoEnabled ? Icons.videocam : Icons.videocam_off,
                      onTap: _toggleVideo,
                      isActive: _localVideoEnabled,
                      activeColor: Colors.white.withOpacity(0.2),
                      inactiveColor: Colors.white.withOpacity(0.2),
                    ),
                    // Emoji (gris foncé)
                    _buildMeetControlButton(
                      icon: Icons.emoji_emotions_outlined,
                      onTap: () {
                        _showReactionMenu();
                      },
                      isActive: true,
                      activeColor: Colors.white.withOpacity(0.2),
                    ),
                    // Plus d'options (gris foncé)
                    _buildMeetControlButton(
                      icon: Icons.more_vert,
                      onTap: _showMoreOptions,
                      isActive: true,
                      activeColor: Colors.white.withOpacity(0.2),
                    ),
                    // Raccrocher (rouge)
                    GestureDetector(
                      onTap: _showLeaveDialog,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEA4335), // Rouge Google Meet
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.call_end,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Vue quand on attend des participants (style Google Meet)
  Widget _buildWaitingView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(flex: 2),
        // Icône utilisateur ou vidéo locale
        Container(
          width: 120,
          height: 160,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: _localVideoEnabled
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AgoraVideoView(
                    controller: VideoViewController(
                      rtcEngine: _engine!,
                      canvas: const VideoCanvas(uid: 0),
                    ),
                  ),
                )
              : const Center(
                  child: Icon(
                    Icons.person,
                    color: AppColors.white,
                    size: 60,
                  ),
                ),
        ),
        const SizedBox(height: 40),
        // Message "Vous êtes le seul participant"
        const Text(
          'Vous êtes le seul participant',
          style: TextStyle(
            color: AppColors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        // Texte explicatif
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'En attente d\'autres participants...',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ),
        const Spacer(flex: 3),
      ],
    );
  }

  /// Bouton de contrôle style Google Meet
  Widget _buildMeetControlButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isActive,
    required Color activeColor,
    Color? inactiveColor,
  }) {
    final bgColor = isActive ? activeColor : (inactiveColor ?? activeColor);
    final iconColor = isActive ? AppColors.white : AppColors.white;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: 24,
        ),
      ),
    );
  }

  /// Affiche le menu des réactions emoji
  void _showReactionMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.navy,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Réactions',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: [
                  _buildEmojiButton('❤️'),
                  _buildEmojiButton('👍'),
                  _buildEmojiButton('👏'),
                  _buildEmojiButton('😂'),
                  _buildEmojiButton('😮'),
                  _buildEmojiButton('😢'),
                  _buildEmojiButton('🤔'),
                  _buildEmojiButton('👋'),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// Bouton emoji
  Widget _buildEmojiButton(String emoji) {
    return GestureDetector(
      onTap: () {
        _sendReaction(emoji);
        Navigator.pop(context);
      },
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            emoji,
            style: const TextStyle(fontSize: 28),
          ),
        ),
      ),
    );
  }

  /// Envoie une réaction emoji
  void _sendReaction(String emoji) {
    // Ajouter la réaction localement
    setState(() {
      _floatingReactions.add({
        'emoji': emoji,
        'x': 0.5 + (DateTime.now().millisecond % 100 - 50) / 100, // Position aléatoire
        'time': DateTime.now(),
      });
    });
    
    // Supprimer après 2 secondes
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          if (_floatingReactions.isNotEmpty) {
            _floatingReactions.removeAt(0);
          }
        });
      }
    });
    
    // Envoyer aux autres participants via le stream
    if (_chatStreamId != null) {
      try {
        final message = jsonEncode({'type': 'reaction', 'emoji': emoji});
        final data = Uint8List.fromList(message.codeUnits);
        _engine?.sendStreamMessage(
          streamId: _chatStreamId!,
          data: data,
          length: data.length,
        );
        debugPrint('✅ Réaction envoyée: $emoji');
      } catch (e) {
        debugPrint('❌ Erreur envoi réaction: $e');
      }
    }
    
    // Feedback visuel
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Vous avez réagi avec $emoji'),
        duration: const Duration(seconds: 1),
        backgroundColor: AppColors.gold.withOpacity(0.9),
      ),
    );
  }

  /// Affiche le menu "Plus d'options"
  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.navy,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Indicateur de drag
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.people_outline, color: Colors.white),
                title: const Text('Participants', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showParticipantsPanel();
                },
              ),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                title: const Text('Chat', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showChatPanel();
                },
              ),
              ListTile(
                leading: Icon(
                  _isScreenSharing ? Icons.stop_screen_share : Icons.screen_share,
                  color: _isScreenSharing ? Colors.red : Colors.white,
                ),
                title: Text(
                  _isScreenSharing ? 'Arrêter le partage' : 'Partager l\'écran',
                  style: TextStyle(color: _isScreenSharing ? Colors.red : Colors.white),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _toggleScreenSharing();
                },
              ),
              if (_isRecording)
                ListTile(
                  leading: const Icon(Icons.fiber_manual_record, color: Colors.red),
                  title: const Text('Enregistrement en cours...', style: TextStyle(color: Colors.red)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('LIVE', style: TextStyle(color: Colors.red, fontSize: 10)),
                  ),
                ),
              ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.white),
                title: const Text('Infos de la réunion', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showMeetingInfo();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Affiche le panneau des participants
  void _showParticipantsPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.navy,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Participants (${_remoteUids.length + 1})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: _remoteUids.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildParticipantTile('Vous (Animateur)', true, true, _localAudioEnabled, isHandRaised: _isHandRaised);
                  }
                  return _buildParticipantTile('Participant $index', false, false, true, isHandRaised: _raisedHands.contains(index));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Widget pour un participant dans la liste
  Widget _buildParticipantTile(String name, bool isMe, bool isHost, bool isUnmuted, {bool isHandRaised = false}) {
    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor: isHost ? AppColors.gold : Colors.grey,
            child: Text(
              name[0].toUpperCase(),
              style: TextStyle(
                color: isHost ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (isHandRaised)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.navy, width: 1),
                ),
                child: const Text('✋', style: TextStyle(fontSize: 10)),
              ),
            ),
        ],
      ),
      title: Text(
        name,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
      ),
      subtitle: isHandRaised
          ? const Text('Main levée', style: TextStyle(color: AppColors.gold, fontSize: 12))
          : (isHost ? const Text('Animateur', style: TextStyle(color: AppColors.gold, fontSize: 12)) : null),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isHandRaised)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.front_hand, color: AppColors.gold, size: 18),
            ),
          Icon(
            isUnmuted ? Icons.mic_rounded : Icons.mic_off_rounded,
            color: isUnmuted ? Colors.white : Colors.red,
            size: 20,
          ),
        ],
      ),
    );
  }

  /// ─── CHAT ───
  /// Affiche le panel de chat
  void _showChatPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final chatController = TextEditingController();
          final scrollController = ScrollController();
          
          // Fonction pour envoyer un message
          void sendMessage() async {
            final text = chatController.text.trim();
            if (text.isEmpty) return;
            
            // Ajouter à la liste locale
            setState(() {
              _chatMessages.add({
                'sender': 'Vous',
                'message': text,
                'isMe': true,
                'timestamp': DateTime.now(),
              });
            });
            setModalState(() {});
            
            // Envoyer à tous les participants via Agora Stream Message
            if (_chatStreamId != null) {
              try {
                final data = Uint8List.fromList(text.codeUnits);
                await _engine?.sendStreamMessage(
                  streamId: _chatStreamId!,
                  data: data,
                  length: data.length,
                );
                debugPrint('✅ Message envoyé: $text');
              } catch (e) {
                debugPrint('❌ Erreur envoi message: $e');
              }
            } else {
              debugPrint('⚠️ Stream non créé, message en local uniquement');
            }
            
            chatController.clear();
            
            // Scroll vers le bas
            Future.delayed(const Duration(milliseconds: 100), () {
              if (scrollController.hasClients) {
                scrollController.animateTo(
                  scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            });
          }
          
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.white.withOpacity(0.1),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Messages',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.white),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                
                // Liste des messages
                Expanded(
                  child: _chatMessages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 48,
                                color: AppColors.white.withOpacity(0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Aucun message',
                                style: TextStyle(
                                  color: AppColors.white.withOpacity(0.5),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _chatMessages.length,
                          itemBuilder: (context, index) {
                            final msg = _chatMessages[index];
                            final isMe = msg['isMe'] as bool;
                            
                            return Align(
                              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? AppColors.gold.withOpacity(0.9)
                                      : Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16).copyWith(
                                    bottomRight: isMe ? const Radius.circular(4) : null,
                                    bottomLeft: !isMe ? const Radius.circular(4) : null,
                                  ),
                                ),
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!isMe)
                                      Text(
                                        msg['sender'] as String,
                                        style: TextStyle(
                                          color: AppColors.gold,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    if (!isMe) const SizedBox(height: 4),
                                    Text(
                                      msg['message'] as String,
                                      style: TextStyle(
                                        color: isMe ? AppColors.navy : AppColors.white,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                
                // Zone de saisie
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.darkBlue,
                    border: Border(
                      top: BorderSide(
                        color: AppColors.white.withOpacity(0.1),
                      ),
                    ),
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: chatController,
                            style: const TextStyle(color: AppColors.white),
                            decoration: InputDecoration(
                              hintText: 'Écrivez un message...',
                              hintStyle: TextStyle(
                                color: AppColors.white.withOpacity(0.5),
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.1),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                            ),
                            onSubmitted: (_) => sendMessage(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: sendMessage,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.gold,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.send,
                              color: AppColors.navy,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Affiche une erreur
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Affiche un message de succès
  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Affiche les infos de la réunion
  void _showMeetingInfo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.navy,
        title: const Text('Infos de la réunion', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${widget.roomId}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text('Titre: ${widget.title}', style: const TextStyle(color: Colors.white70)),
            if (_conferenceId != null)
              Text('Conférence: $_conferenceId', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text('Participants: ${_remoteUids.length + 1}', style: const TextStyle(color: Colors.white70)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('FERMER', style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );
  }
}
