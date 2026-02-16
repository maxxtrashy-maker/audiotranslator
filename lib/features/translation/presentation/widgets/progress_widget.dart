import 'package:flutter/material.dart';

class ProgressWidget extends StatelessWidget {
  final double progress;

  const ProgressWidget({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text("Traitement en cours..."),
        const SizedBox(height: 10),
        LinearProgressIndicator(value: progress),
        const SizedBox(height: 5),
        Text("${(progress * 100).toInt()}%"),
      ],
    );
  }
}
