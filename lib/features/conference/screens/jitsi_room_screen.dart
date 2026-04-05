import 'dart:io';
import 'dart:convert';
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
  String? _error;
  final List<int> _remoteUids = [];

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  @override
  void dispose() {
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
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
          if (mounted) setState(() => _isInitializing = false);
        },
        onUserJoined: (connection, uid, elapsed) {
          debugPrint('Agora: utilisateur $uid a rejoint');
          if (mounted) setState(() => _remoteUids.add(uid));
        },
        onUserOffline: (connection, uid, reason) {
          if (mounted) setState(() => _remoteUids.remove(uid));
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

  Future<void> _leaveChannel() async {
    await _engine?.leaveChannel();
    if (mounted) Navigator.pop(context);
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

        // Header
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.8), Colors.transparent],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: _leaveChannel,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          overflow: TextOverflow.ellipsis),
                      Row(children: [
                        const Icon(Icons.circle, color: Colors.red, size: 8),
                        const SizedBox(width: 4),
                        Text(
                          _remoteUids.isEmpty ? 'EN ATTENTE' : '${_remoteUids.length + 1} PARTICIPANTS',
                          style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Boutons de contrôle
        Positioned(
          bottom: 30, left: 0, right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Micro
              _buildControlButton(
                icon: _localAudioEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
                color: _localAudioEnabled ? Colors.white : Colors.redAccent,
                bgColor: Colors.black54,
                onTap: _toggleAudio,
              ),
              const SizedBox(width: 20),
              // Raccrocher
              _buildControlButton(
                icon: Icons.call_end_rounded,
                color: Colors.white,
                bgColor: Colors.redAccent,
                size: 64,
                onTap: _leaveChannel,
              ),
              const SizedBox(width: 20),
              // Caméra
              _buildControlButton(
                icon: _localVideoEnabled ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                color: _localVideoEnabled ? Colors.white : Colors.redAccent,
                bgColor: Colors.black54,
                onTap: _toggleVideo,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
    double size = 52,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
        child: Icon(icon, color: color, size: size * 0.45),
      ),
    );
  }
}
