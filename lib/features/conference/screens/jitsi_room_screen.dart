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
  String _status = 'Connexion en cours...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _joinRoom());
  }

  Future<void> _joinRoom() async {
    setState(() { _error = null; _status = 'Connexion en cours...'; });

    final user = LocalStorageService().getUser();

    final listener = JitsiMeetEventListener(
      conferenceJoined: (url) {
        if (mounted) setState(() => _status = 'Connecté ✅');
      },
      conferenceTerminated: (url, error) {
        if (mounted) Navigator.pop(context);
      },
      conferenceWillJoin: (url) {
        if (mounted) setState(() => _status = 'Connexion à la salle...');
      },
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
            'disableDeepLinking': true,
            'prejoinPageEnabled': false,
          },
          featureFlags: {
            'welcomepage.enabled': false,
            'pip.enabled': true,
            'chat.enabled': true,
            'raise-hand.enabled': true,
            'recording.enabled': false,
            'live-streaming.enabled': false,
            'prejoinpage.enabled': false,
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
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppColors.gold),
                  const SizedBox(height: 20),
                  Text(_status, style: const TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('La latence réseau peut allonger ce délai.',
                      style: TextStyle(color: AppColors.grey, fontSize: 12)),
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.darkBlue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi_rounded, color: AppColors.gold, size: 16),
                        const SizedBox(width: 8),
                        Text('meet.jit.si', style: const TextStyle(color: AppColors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
