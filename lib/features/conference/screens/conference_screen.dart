import 'package:flutter/material.dart';
import '../../../core/res/styles.dart';

class ConferenceScreen extends StatelessWidget {
  const ConferenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Conference Screen (Soon)', style: TextStyle(color: AppColors.white)),
      ),
    );
  }
}
