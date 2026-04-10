import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/res/styles.dart';
import '../../../core/network/api_service.dart';

class JitsiRoomScreen extends StatefulWidget {
  final String roomId;
  final String title;

  const JitsiRoomScreen({
    super.key,
    required this.roomId,
    required this.title,
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
  
  /// Envoie une réaction emoji
  void _sendReaction(String emoji) {
    // Afficher localement
    setState(() {
      _floatingReactions.add({
        'emoji': emoji,
        'x': 0.5 + (0.2 * (0.5 - (DateTime.now().millisecond % 100) / 100)),
        'y': 0.8,
        'time': DateTime.now(),
      });
    });
    
    // Supprimer après animation
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          if (_floatingReactions.isNotEmpty) {
            _floatingReactions.removeAt(0);
          }
        });
      }
    });
    
    // TODO: Envoyer aux autres participants via Agora
  }

  @override
  void initState() {
    super.initState();
    _initConferenceAndRecording();
  }

  /// Initialise la conférence et démarre l'enregistrement automatique
  Future<void> _initConferenceAndRecording() async {
    await _initAgora();
    if (_error == null && mounted) {
      await _startRecording();
    }
  }

  /// Démarre l'enregistrement automatique
  Future<void> _startRecording() async {
    try {
      // Extraire l'ID de conférence du roomId (format: bts-{timestamp}-{random})
      // Ou utiliser une autre méthode pour obtenir l'ID
      final response = await ApiService().post('/conferences', {
        'title': widget.title,
      });

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        _conferenceId = data['id'];

        // Démarrer l'enregistrement Agora
        final recordingRes = await ApiService().post('/agora/recording/start', {
          'conferenceId': _conferenceId,
          'channelName': _channelName,
        });

        if (recordingRes.statusCode == 200) {
          setState(() => _isRecording = true);
          debugPrint('🎥 Enregistrement démarré pour conférence $_conferenceId');
        }
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
        onJoinChannelSuccess: (connection, elapsed) {
          debugPrint('Agora: canal rejoint avec succès');
          _startCallTimer(); // Démarrer le timer de l'appel
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
      await _engine?.stopScreenCapture();
      setState(() => _isScreenSharing = false);
    } else {
      // Démarrer le partage d'écran
      try {
        await _engine?.startScreenCapture(const ScreenCaptureParameters2(
          captureAudio: true,
          captureVideo: true,
        ));
        setState(() => _isScreenSharing = true);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📺 Partage d\'écran activé'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        debugPrint('Erreur partage écran: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur partage d\'écran: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
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

  Widget _buildConference() {
    return Stack(
      children: [
        // Vidéo distante (plein écran)
        _remoteUids.isEmpty
            ? Container(
                color: AppColors.darkBlue,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_rounded, color: AppColors.grey, size: 80),
                      SizedBox(height: 12),
                      Text('En attente d\'un participant...', style: TextStyle(color: AppColors.grey)),
                    ],
                  ),
                ),
              )
            : AgoraVideoView(
                controller: VideoViewController.remote(
                  rtcEngine: _engine!,
                  canvas: VideoCanvas(uid: _remoteUids.first),
                  connection: RtcConnection(channelId: _channelName),
                ),
              ),

        // Vidéo locale (coin supérieur droit)
        Positioned(
          top: 70,
          right: 12,
          child: Container(
            width: 100,
            height: 140,
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
                        child: Icon(Icons.videocam_off_rounded, color: AppColors.grey, size: 30),
                      ),
                    ),
            ),
          ),
        ),

        // Header moderne style Meet
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Bouton retour
                  _buildIconButton(
                    Icons.arrow_back_ios_rounded,
                    onTap: _showLeaveDialog,
                    bgColor: Colors.black26,
                  ),
                  const SizedBox(width: 12),
                  // Info salle
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: _isRecording ? Colors.red : (_remoteUids.isEmpty ? Colors.orange : Colors.green),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isRecording
                                    ? 'Enregistrement...'
                                    : (_remoteUids.isEmpty ? 'En attente' : '${_remoteUids.length + 1} participants'),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Horloge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _formatDuration(_callDuration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Réactions emoji flottantes
        ..._buildFloatingReactions(),
        
        // Contrôles centrés en bas style Meet
        Positioned(
          bottom: 30,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(24),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Barre de réactions rapides
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildReactionButton('❤️'),
                        _buildReactionButton('👍'),
                        _buildReactionButton('👏'),
                        _buildReactionButton('😂'),
                        _buildReactionButton('😮'),
                        _buildReactionButton('😢'),
                        _buildReactionButton('🤔'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Barre de contrôles principaux
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Micro
                      _buildControlButton(
                        icon: _localAudioEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
                        onTap: _toggleAudio,
                        label: 'Micro',
                        isActive: _localAudioEnabled,
                      ),
                      // Caméra
                      _buildControlButton(
                        icon: _localVideoEnabled ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                        onTap: _toggleVideo,
                        label: 'Vidéo',
                        isActive: _localVideoEnabled,
                      ),
                      // Lever de main
                      _buildControlButton(
                        icon: _isHandRaised ? Icons.front_hand : Icons.front_hand_outlined,
                        onTap: _toggleHandRaise,
                        label: 'Main',
                        isActive: _isHandRaised,
                      ),
                      // Partage d'écran
                      _buildControlButton(
                        icon: _isScreenSharing ? Icons.stop_screen_share : Icons.screen_share,
                        onTap: _toggleScreenSharing,
                        label: 'Écran',
                        isActive: _isScreenSharing,
                      ),
                      // Plus d'options
                      _buildControlButton(
                        icon: Icons.more_vert_rounded,
                        onTap: _showMoreOptions,
                        label: 'Plus',
                        isActive: true,
                      ),
                      // Quitter (gros bouton rouge)
                      GestureDetector(
                        onTap: _showLeaveDialog,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.redAccent.withOpacity(0.4),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.call_end_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Raccrocher',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Construit les réactions emoji flottantes
  List<Widget> _buildFloatingReactions() {
    return _floatingReactions.map((reaction) {
      return Positioned(
        left: reaction['x'] * MediaQuery.of(context).size.width,
        bottom: 150 + (DateTime.now().difference(reaction['time']).inMilliseconds / 10),
        child: Opacity(
          opacity: 1 - (DateTime.now().difference(reaction['time']).inMilliseconds / 2000),
          child: Text(
            reaction['emoji'],
            style: const TextStyle(fontSize: 32),
          ),
        ),
      );
    }).toList();
  }

  /// Bouton de réaction emoji
  Widget _buildReactionButton(String emoji) {
    return GestureDetector(
      onTap: () => _sendReaction(emoji),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white10,
          shape: BoxShape.circle,
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 20)),
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

  /// Affiche le panneau de chat
  void _showChatPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.navy,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'Chat',
                    style: TextStyle(
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
              child: _chatMessages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline, color: Colors.grey, size: 48),
                          SizedBox(height: 16),
                          Text(
                            'Aucun message',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: controller,
                      itemCount: _chatMessages.length,
                      itemBuilder: (context, index) {
                        final msg = _chatMessages[index];
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.gold,
                            child: Text(
                              msg['sender'][0].toUpperCase(),
                              style: const TextStyle(fontSize: 12, color: Colors.black),
                            ),
                          ),
                          title: Text(
                            msg['sender'],
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            msg['message'],
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        );
                      },
                    ),
            ),
            // Zone de saisie
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black12,
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Envoyer un message...',
                        hintStyle: TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white10,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sendChatMessage,
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.send, color: Colors.black, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Envoie un message dans le chat
  void _sendChatMessage() {
    if (_chatController.text.trim().isEmpty) return;
    setState(() {
      _chatMessages.add({
        'sender': 'Vous',
        'message': _chatController.text.trim(),
        'time': DateTime.now(),
      });
      _chatController.clear();
    });
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
            Text('Titre:', style: TextStyle(color: Colors.grey, fontSize: 12)),
            Text(widget.title, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('ID de la salle:', style: TextStyle(color: Colors.grey, fontSize: 12)),
            SelectableText(
              widget.roomId,
              style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 12),
            Text('Durée:', style: TextStyle(color: Colors.grey, fontSize: 12)),
            Text(_formatDuration(_callDuration), style: TextStyle(color: Colors.white)),
            const SizedBox(height: 12),
            Text('Participants:', style: TextStyle(color: Colors.grey, fontSize: 12)),
            Text('${_remoteUids.length + 1}', style: TextStyle(color: Colors.white)),
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
