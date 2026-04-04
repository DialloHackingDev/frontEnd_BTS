import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../core/res/styles.dart';

class AudioPlayerScreen extends StatefulWidget {
  final String title;
  final String url;

  const AudioPlayerScreen({super.key, required this.title, required this.url});

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMsg = '';

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await _controller.initialize();
      _controller.addListener(() {
        if (mounted) setState(() {});
      });
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      if (mounted) setState(() { _hasError = true; _errorMsg = e.toString(); });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Now Playing'),
        centerTitle: true,
      ),
      body: _hasError
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 60),
                  const SizedBox(height: 16),
                  const Text('Impossible de lire ce fichier.', style: TextStyle(color: AppColors.white, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(_errorMsg, style: const TextStyle(color: AppColors.grey, fontSize: 11), textAlign: TextAlign.center),
                ],
              ),
            )
          : !_isInitialized
              ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 40),

                      // Artwork
                      Container(
                        width: 220, height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.darkBlue,
                          boxShadow: [BoxShadow(color: AppColors.gold.withOpacity(0.15), blurRadius: 40, spreadRadius: 10)],
                          border: Border.all(color: AppColors.gold.withOpacity(0.3), width: 2),
                        ),
                        child: const Icon(Icons.audiotrack_rounded, color: AppColors.gold, size: 80),
                      ),

                      const SizedBox(height: 40),

                      // Titre
                      Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text('BTS Library', style: TextStyle(color: AppColors.grey, fontSize: 14)),

                      const SizedBox(height: 40),

                      // Slider progression
                      ValueListenableBuilder(
                        valueListenable: _controller,
                        builder: (_, VideoPlayerValue value, __) {
                          final position = value.position;
                          final duration = value.duration;
                          final progress = duration.inMilliseconds > 0
                              ? position.inMilliseconds / duration.inMilliseconds
                              : 0.0;

                          return Column(
                            children: [
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: AppColors.gold,
                                  inactiveTrackColor: AppColors.white.withOpacity(0.1),
                                  thumbColor: AppColors.gold,
                                  overlayColor: AppColors.gold.withOpacity(0.2),
                                  trackHeight: 4,
                                ),
                                child: Slider(
                                  value: progress.clamp(0.0, 1.0),
                                  onChanged: (v) {
                                    final newPos = Duration(milliseconds: (v * duration.inMilliseconds).round());
                                    _controller.seekTo(newPos);
                                  },
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(_formatDuration(position), style: const TextStyle(color: AppColors.grey, fontSize: 12)),
                                    Text(_formatDuration(duration), style: const TextStyle(color: AppColors.grey, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 30),

                      // Contrôles
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.replay_10_rounded, color: AppColors.white, size: 36),
                            onPressed: () {
                              final newPos = _controller.value.position - const Duration(seconds: 10);
                              _controller.seekTo(newPos < Duration.zero ? Duration.zero : newPos);
                            },
                          ),
                          GestureDetector(
                            onTap: () {
                              _controller.value.isPlaying ? _controller.pause() : _controller.play();
                            },
                            child: Container(
                              width: 72, height: 72,
                              decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                              child: Icon(
                                _controller.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: AppColors.navy, size: 44,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.forward_10_rounded, color: AppColors.white, size: 36),
                            onPressed: () {
                              final duration = _controller.value.duration;
                              final newPos = _controller.value.position + const Duration(seconds: 10);
                              _controller.seekTo(newPos > duration ? duration : newPos);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }
}
