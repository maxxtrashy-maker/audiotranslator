import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/translation_provider.dart';
import '../widgets/file_upload_widget.dart';
import '../widgets/progress_widget.dart';
import '../widgets/download_widget.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(translationProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('AudioTranslate - Magie du Son')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
               if (state.errorMessage != null)
                 Container(
                   padding: const EdgeInsets.all(8),
                   color: Colors.red.shade100,
                   child: Text(state.errorMessage!, style: const TextStyle(color: Colors.red)),
                 ),
               const SizedBox(height: 20),

               if (!state.isLoading && state.audioFile == null)
                  FileUploadWidget(
                    onFileSelected: (file) {
                      ref.read(translationProvider.notifier).processAudio(file);
                    },
                  ),

               if (state.isLoading)
                  ProgressWidget(progress: state.progress),

               if (state.transcription != null) ...[
                 const SizedBox(height: 10),
                 const Text("Transcription:", style: TextStyle(fontWeight: FontWeight.bold)),
                 Text(state.transcription!),
               ],

               if (state.translation != null) ...[
                 const SizedBox(height: 10),
                 const Text("Traduction (Français):", style: TextStyle(fontWeight: FontWeight.bold)),
                 Text(state.translation!),
               ],

               if (state.audioFile != null) ...[
                 const SizedBox(height: 20),
                 DownloadWidget(file: state.audioFile!),
                 const SizedBox(height: 10),
                 ElevatedButton(
                   onPressed: () => ref.read(translationProvider.notifier).reset(),
                   child: const Text("Recommencer"),
                 )
               ]
            ],
          ),
        ),
      ),
    );
  }
}
