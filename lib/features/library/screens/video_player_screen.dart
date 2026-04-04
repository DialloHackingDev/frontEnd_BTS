import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../../core/res/styles.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String title;
  final String url;

  const VideoPlayerScreen({super.key, required this.title, required this.url});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _showControls = true;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await _controller.initialize();
      _controller.addListener(() { if (mounted) setState(() {}); });
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _toggleFullscreen() {
    setState(() => _isFullscreen = !_isFullscreen);
    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _isFullscreen ? null : AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.title, style: const TextStyle(color: AppColors.white, fontSize: 16)),
      ),
      body: _hasError
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 60),
                  const SizedBox(height: 16),
                  const Text('Impossible de lire cette vidéo.', style: TextStyle(color: AppColors.white)),
                  const SizedBox(height: 8),
                  const Text('Vérifiez que le lien est valide et accessible.',
                      style: TextStyle(color: AppColors.grey, fontSize: 12)),
                ],
              ),
            )
          : !_isInitialized
              ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
              : GestureDetector(
                  onTap: () => setState(() => _showControls = !_showControls),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Vidéo
                      Center(
                        child: AspectRatio(
                          aspectRatio: _controller.value.aspectRatio,
                          child: VideoPlayer(_controller),
                        ),
                      ),

                      // Overlay contrôles
                      if (_showControls)
                        Container(
                          color: Colors.black.withOpacity(0.4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // Bouton play/pause central
                              Expanded(
                                child: Center(
                                  child: GestureDetector(
                                    onTap: () {
                                      _controller.value.isPlaying
                                          ? _controller.pause()
                                          : _controller.play();
                                    },
                                    child: Container(
                                      width: 64, height: 64,
                                      decoration: BoxDecoration(
                                        color: AppColors.gold.withOpacity(0.9),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _controller.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                        color: AppColors.navy, size: 40,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // Barre de progression + durée
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Column(
                                  children: [
                                    ValueListenableBuilder(
                                      valueListenable: _controller,
                                      builder: (_, VideoPlayerValue value, __) {
                                        final pos = value.position;
                                        final dur = value.duration;
                                        final progress = dur.inMilliseconds > 0
                                            ? pos.inMilliseconds / dur.inMilliseconds
                                            : 0.0;
                                        return Column(
                                          children: [
                                            SliderTheme(
                                              data: SliderTheme.of(context).copyWith(
                                                activeTrackColor: AppColors.gold,
                                                inactiveTrackColor: Colors.white24,
                                                thumbColor: AppColors.gold,
                                                trackHeight: 3,
                                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                              ),
                                              child: Slider(
                                                value: progress.clamp(0.0, 1.0),
                                                onChanged: (v) {
                                                  _controller.seekTo(Duration(
                                                      milliseconds: (v * dur.inMilliseconds).round()));
                                                },
                                              ),
                                            ),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(_formatDuration(pos),
                                                    style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                                Text(_formatDuration(dur),
                                                    style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                              ],
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        // -10s
                                        IconButton(
                                          icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
                                          onPressed: () {
                                            final p = _controller.value.position - const Duration(seconds: 10);
                                            _controller.seekTo(p < Duration.zero ? Duration.zero : p);
                                          },
                                        ),
                                        // +10s
                                        IconButton(
                                          icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
                                          onPressed: () {
                                            final d = _controller.value.duration;
                                            final p = _controller.value.position + const Duration(seconds: 10);
                                            _controller.seekTo(p > d ? d : p);
                                          },
                                        ),
                                        // Fullscreen
                                        IconButton(
                                          icon: Icon(
                                            _isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                                            color: Colors.white,
                                          ),
                                          onPressed: _toggleFullscreen,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                  ],
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
}
