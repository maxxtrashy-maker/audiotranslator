import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class DownloadWidget extends StatelessWidget {
  final File file;

  const DownloadWidget({super.key, required this.file});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: 10),
            const Text("Fichier audio généré avec succès !"),
            const SizedBox(height: 10),
            Text("Chemin: ${file.path}", style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Télécharger / Partager'),
              onPressed: () async {
                // ignore: deprecated_member_use
                await Share.shareXFiles([XFile(file.path)], text: 'Voici votre fichier audio traduit !');
              },
            ),
          ],
        ),
      ),
    );
  }
}
