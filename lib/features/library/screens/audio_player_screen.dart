import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import '../../../core/res/styles.dart';
import '../../../core/services/cache_service.dart';

class AudioPlayerScreen extends StatefulWidget {
  final String title;
  final String url;

  const AudioPlayerScreen({super.key, required this.title, required this.url});

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  late AudioPlayer _player;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _errorMsg = '';
  String? _cachedPath;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      // Configuration de la session audio
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());
      
      // Écouter les événements de la session
      session.interruptionEventStream.listen((event) {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _player.setVolume(0.5);
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              _player.pause();
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _player.setVolume(1.0);
              break;
            case AudioInterruptionType.pause:
              _player.play();
              break;
            default:
              break;
          }
        }
      });

      // Écouter les changements de position
      _player.positionStream.listen((position) {
        if (mounted) setState(() => _position = position);
      });

      // Écouter les changements de durée
      _player.durationStream.listen((duration) {
        if (mounted && duration != null) {
          setState(() => _duration = duration);
        }
      });

      // Vérifier le cache ou télécharger
      await _loadAudioSource();

    } catch (e) {
      if (mounted) setState(() { _hasError = true; _errorMsg = e.toString(); });
    }
  }

  Future<void> _loadAudioSource() async {
    setState(() => _isDownloading = true);
    
    try {
      // Vérifier si le fichier est déjà en cache
      _cachedPath = await CacheService.getCachedFile(widget.url);
      
      if (_cachedPath != null) {
        // Utiliser le fichier cache
        await _player.setFilePath(_cachedPath!);
        if (mounted) {
          setState(() {
            _isInitialized = true;
            _isDownloading = false;
          });
        }
      } else {
        // Télécharger et mettre en cache avec progression
        _cachedPath = await CacheService.downloadAndCache(
          widget.url,
          fileType: 'audio',
          onProgress: (progress) {
            if (mounted) setState(() => _downloadProgress = progress);
          },
        );
        
        await _player.setFilePath(_cachedPath!);
        if (mounted) {
          setState(() {
            _isInitialized = true;
            _isDownloading = false;
          });
        }
      }
    } catch (e) {
      // Fallback: lecture directe depuis l'URL
      try {
        await _player.setUrl(widget.url);
        if (mounted) {
          setState(() {
            _isInitialized = true;
            _isDownloading = false;
          });
        }
      } catch (fallbackError) {
        if (mounted) {
          setState(() { 
            _hasError = true; 
            _isDownloading = false;
            _errorMsg = 'Impossible de charger l\'audio: ${e.toString()}'; 
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
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
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _hasError = false;
                        _isInitialized = false;
                      });
                      _loadAudioSource();
                    },
                    icon: const Icon(Icons.refresh_rounded, color: AppColors.navy),
                    label: const Text('RÉESSAYER', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
                  ),
                ],
              ),
            )
          : _isDownloading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: CircularProgressIndicator(
                          value: _downloadProgress > 0 ? _downloadProgress : null,
                          color: AppColors.gold,
                          strokeWidth: 4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _downloadProgress > 0 
                          ? 'Téléchargement ${(_downloadProgress * 100).toInt()}%'
                          : 'Préparation...',
                        style: const TextStyle(color: AppColors.grey, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Ce fichier sera disponible hors ligne',
                        style: TextStyle(color: AppColors.grey, fontSize: 11),
                      ),
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
                      StreamBuilder<Duration>(
                        stream: _player.positionStream,
                        builder: (context, snapshot) {
                          final position = snapshot.data ?? Duration.zero;
                          final progress = _duration.inMilliseconds > 0
                              ? position.inMilliseconds / _duration.inMilliseconds
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
                                    final newPos = Duration(milliseconds: (v * _duration.inMilliseconds).round());
                                    _player.seek(newPos);
                                  },
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(_formatDuration(position), style: const TextStyle(color: AppColors.grey, fontSize: 12)),
                                    Text(_formatDuration(_duration), style: const TextStyle(color: AppColors.grey, fontSize: 12)),
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
                              final newPos = _position - const Duration(seconds: 10);
                              _player.seek(newPos < Duration.zero ? Duration.zero : newPos);
                            },
                          ),
                          StreamBuilder<PlayerState>(
                            stream: _player.playerStateStream,
                            builder: (context, snapshot) {
                              final playerState = snapshot.data;
                              final isPlaying = playerState?.playing ?? false;
                              final processingState = playerState?.processingState ?? ProcessingState.idle;
                              
                              return GestureDetector(
                                onTap: () {
                                  isPlaying ? _player.pause() : _player.play();
                                },
                                child: Container(
                                  width: 72, height: 72,
                                  decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                                  child: processingState == ProcessingState.buffering || processingState == ProcessingState.loading
                                    ? const SizedBox(
                                        width: 24, height: 24,
                                        child: CircularProgressIndicator(
                                          color: AppColors.navy,
                                          strokeWidth: 3,
                                        ),
                                      )
                                    : Icon(
                                        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                        color: AppColors.navy, size: 44,
                                      ),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.forward_10_rounded, color: AppColors.white, size: 36),
                            onPressed: () {
                              final newPos = _position + const Duration(seconds: 10);
                              _player.seek(newPos > _duration ? _duration : newPos);
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
