import 'package:flutter/material.dart';
import '../../../core/res/styles.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Library Screen (Soon)', style: TextStyle(color: AppColors.white)),
      ),
    );
  }
}
