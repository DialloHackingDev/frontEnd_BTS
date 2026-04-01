import 'package:flutter/material.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import '../../../core/res/styles.dart';
import '../../../core/storage/local_storage_service.dart';

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
  final JitsiMeet _jitsiMeet = JitsiMeet();
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _joinRoom());
  }

  Future<void> _joinRoom() async {
    setState(() { _error = null; });

    final user = LocalStorageService().getUser();

    final listener = JitsiMeetEventListener(
      conferenceJoined: (url) {},
      conferenceTerminated: (url, error) {
        if (mounted) Navigator.pop(context);
      },
      conferenceWillJoin: (url) {},
    );

    try {
      await _jitsiMeet.join(
        JitsiMeetConferenceOptions(
          serverURL: 'https://meet.jit.si',
          room: widget.roomId,
          configOverrides: {
            'startWithAudioMuted': false,
            'startWithVideoMuted': false,
            'subject': widget.title,
          },
          featureFlags: {
            'welcomepage.enabled': false,
            'pip.enabled': true,
            'chat.enabled': true,
            'raise-hand.enabled': true,
            'recording.enabled': false,
            'live-streaming.enabled': false,
          },
          userInfo: JitsiMeetUserInfo(
            displayName: user?['name'] ?? 'Membre BTS',
            email: user?['email'] ?? '',
          ),
        ),
        listener,
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title,
                style: const TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const Row(children: [
              Icon(Icons.circle, color: Colors.red, size: 8),
              SizedBox(width: 4),
              Text('EN DIRECT', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
            ]),
          ],
        ),
      ),
      body: Center(
        child: _error != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 60),
                  const SizedBox(height: 16),
                  const Text('Impossible de rejoindre la salle.',
                      style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: AppColors.grey, fontSize: 12), textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _joinRoom,
                    icon: const Icon(Icons.refresh_rounded, color: AppColors.navy),
                    label: const Text('RÉESSAYER', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              )
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.gold),
                  SizedBox(height: 20),
                  Text('Connexion à la salle en cours...', style: TextStyle(color: AppColors.grey, fontSize: 14)),
                  SizedBox(height: 8),
                  Text('Jitsi Meet va s\'ouvrir dans un instant.',
                      style: TextStyle(color: AppColors.grey, fontSize: 12)),
                ],
              ),
      ),
    );
  }
}
