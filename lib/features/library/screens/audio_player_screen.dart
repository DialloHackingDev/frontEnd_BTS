import 'package:flutter/material.dart';
import '../../../core/res/styles.dart';

class AudioPlayerScreen extends StatefulWidget {
  final String title;
  final String url;
  const AudioPlayerScreen({super.key, required this.title, required this.url});

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
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
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert_rounded)),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Large Artwork
              Container(
                width: double.infinity,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.darkBlue,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withOpacity(0.1),
                      blurRadius: 40,
                      spreadRadius: 10,
                    )
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: const DecorationImage(
                        image: NetworkImage('https://images.unsplash.com/photo-1557804506-669a67965ba0?auto=format&fit=crop&q=80&w=1074'),
                        fit: BoxFit.cover,
                      ),
                      border: Border.all(color: AppColors.gold.withOpacity(0.5), width: 2),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Title & Category
              const Text(
                'Psychologie de l\'Investissement',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.white, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Chapter 04: Emotional Intelligence in Markets',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.grey, fontSize: 16),
              ),
              
              const SizedBox(height: 40),
              
              // Progress Bar
              Column(
                children: [
                  Slider(
                    value: 0.35,
                    onChanged: (v) {},
                    activeColor: AppColors.gold,
                    inactiveColor: AppColors.white.withOpacity(0.1),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('14:28', style: TextStyle(color: AppColors.grey, fontSize: 12)),
                        Text('-28:45', style: TextStyle(color: AppColors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 30),
              
              // Playback Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(onPressed: () {}, icon: const Icon(Icons.shuffle, color: AppColors.grey)),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.skip_previous_rounded, color: AppColors.white, size: 40)),
                  Container(
                    width: 70,
                    height: 70,
                    decoration: const BoxDecoration(
                      color: AppColors.gold,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.pause_rounded, color: AppColors.navy, size: 40),
                  ),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.skip_next_rounded, color: AppColors.white, size: 40)),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.repeat, color: AppColors.grey)),
                ],
              ),
              
              const SizedBox(height: 50),
              
              // Modules List (Style Premium)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Masterclass Modules', style: TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 15),
              _buildModuleCard(
                number: '04',
                title: 'Emotional Intelligence',
                duration: '43:13',
                isPlaying: true,
              ),
              const SizedBox(height: 10),
              _buildModuleCard(
                number: '05',
                title: 'The Compound Mindset',
                duration: '28:50',
                isPlaying: false,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModuleCard({required String number, required String title, required String duration, required bool isPlaying}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPlaying ? AppColors.white.withOpacity(0.05) : AppColors.darkBlue,
        borderRadius: BorderRadius.circular(16),
        border: isPlaying ? Border.all(color: AppColors.gold.withOpacity(0.3)) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isPlaying ? AppColors.gold : AppColors.navy,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: isPlaying 
                ? const Icon(Icons.equalizer_rounded, color: AppColors.navy, size: 20)
                : Text(number, style: const TextStyle(color: AppColors.grey, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: isPlaying ? AppColors.gold : AppColors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  isPlaying ? 'Currently Playing' : 'Next in Series',
                  style: const TextStyle(color: AppColors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(duration, style: const TextStyle(color: AppColors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}
