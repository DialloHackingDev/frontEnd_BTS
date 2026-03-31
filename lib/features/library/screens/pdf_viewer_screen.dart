import 'package:flutter/material.dart';
import '../../../core/res/styles.dart';

class PdfViewerScreen extends StatefulWidget {
  final String title;
  final String url;
  const PdfViewerScreen({super.key, required this.title, required this.url});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.gold),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(color: AppColors.white, fontSize: 18),
        ),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert_rounded, color: AppColors.gold)),
        ],
      ),
      body: Stack(
        children: [
          // Simulated PDF Page
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'BORN TO SUCCESS',
                    style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Q4 EXECUTIVE STRATEGY BRIEF',
                    style: TextStyle(color: Colors.grey, fontSize: 8),
                  ),
                  const SizedBox(height: 100),
                  const Text(
                    'Architectural\nGrowth &\nOperational\nExcellence',
                    style: TextStyle(
                      color: AppColors.navy,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: 60,
                    height: 4,
                    color: AppColors.gold,
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    'The transition from linear growth to exponential scaling requires a fundamental shift in institutional architecture. Our "Prestigious Architect" model prioritizes structural integrity over rapid, uncalculated expansion.',
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          
          // Bottom Navigation Bar (Floating Style)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.darkBlue,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.white.withOpacity(0.1)),
              ),
              child: IntrinsicHeight(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(onPressed: () {}, icon: const Icon(Icons.skip_previous_rounded, color: AppColors.grey)),
                    const SizedBox(width: 10),
                    const VerticalDivider(color: AppColors.white, width: 1, indent: 8, endIndent: 8),
                    const SizedBox(width: 15),
                    const Icon(Icons.search, color: AppColors.grey, size: 20),
                    const SizedBox(width: 15),
                    const Text(
                      'PAGE 1 OF 12',
                      style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 10),
                    ),
                    const SizedBox(width: 15),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.zoom_in_rounded, color: AppColors.navy, size: 20),
                    ),
                    const SizedBox(width: 15),
                    const VerticalDivider(color: AppColors.white, width: 1, indent: 8, endIndent: 8),
                    const SizedBox(width: 10),
                    IconButton(onPressed: () {}, icon: const Icon(Icons.skip_next_rounded, color: AppColors.grey)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
