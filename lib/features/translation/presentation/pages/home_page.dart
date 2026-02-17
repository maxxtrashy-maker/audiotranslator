import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/translation_provider.dart';
import '../widgets/file_upload_widget.dart';
import '../widgets/progress_widget.dart';
import '../widgets/download_widget.dart';
import '../widgets/language_selector_widget.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ttsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Elokens')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
               // Error message
               if (state.errorMessage != null)
                 Container(
                   padding: const EdgeInsets.all(12),
                   margin: const EdgeInsets.only(bottom: 16),
                   decoration: BoxDecoration(
                     color: Theme.of(context).colorScheme.errorContainer,
                     borderRadius: BorderRadius.circular(8),
                   ),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Row(
                         children: [
                           Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
                           const SizedBox(width: 8),
                           Expanded(
                             child: Text(
                               state.errorMessage!,
                               style: TextStyle(
                                 color: Theme.of(context).colorScheme.onErrorContainer,
                                 fontWeight: FontWeight.bold,
                               ),
                             ),
                           ),
                         ],
                       ),
                       if (_getSuggestion(state.errorMessage!) != null) ...[
                         const SizedBox(height: 8),
                         Text(
                           _getSuggestion(state.errorMessage!)!,
                           style: TextStyle(
                             color: Theme.of(context).colorScheme.onErrorContainer,
                             fontSize: 12,
                           ),
                         ),
                       ],
                     ],
                   ),
                 ),

               // Language selector (only show when not processing)
               if (!state.isLoading && state.audioFile == null)
                  const LanguageSelectorWidget(),

               const SizedBox(height: 20),

               // Instructions
               if (!state.isLoading && state.audioFile == null)
                 Card(
                   color: Theme.of(context).colorScheme.primaryContainer,
                   child: Padding(
                     padding: const EdgeInsets.all(16.0),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Row(
                           children: [
                             Icon(Icons.info_outline, color: Theme.of(context).colorScheme.onPrimaryContainer),
                             const SizedBox(width: 8),
                             Text(
                               'Instructions',
                               style: TextStyle(
                                 fontWeight: FontWeight.bold,
                                 color: Theme.of(context).colorScheme.onPrimaryContainer,
                               ),
                             ),
                           ],
                         ),
                         const SizedBox(height: 8),
                         Text(
                           '1. Sélectionnez la langue de synthèse vocale\n'
                           '2. Uploadez un fichier .txt contenant votre texte\n'
                           '3. L\'application générera un fichier audio WAV',
                           style: TextStyle(
                             fontSize: 14,
                             color: Theme.of(context).colorScheme.onPrimaryContainer,
                           ),
                         ),
                       ],
                     ),
                   ),
                 ),

               const SizedBox(height: 20),

               // File upload button
               if (!state.isLoading && state.audioFile == null)
                  FileUploadWidget(
                    onFileSelected: (file) {
                      ref.read(ttsProvider.notifier).processTextFile(file);
                    },
                    acceptedExtensions: const ['txt'],
                    buttonText: 'Sélectionner un fichier texte (.txt)',
                  ),

               // Progress indicator with status message
               if (state.isLoading) ...[
                  ProgressWidget(progress: state.progress),
                  if (state.statusMessage != null) ...[
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        state.statusMessage!,
                        style: const TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
               ],

               // Input text preview
               if (state.inputText != null) ...[
                 const SizedBox(height: 20),
                 Card(
                   child: Padding(
                     padding: const EdgeInsets.all(12.0),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         const Row(
                           children: [
                             Icon(Icons.text_fields, size: 20),
                             SizedBox(width: 8),
                             Text(
                               "Texte à synthétiser:",
                               style: TextStyle(fontWeight: FontWeight.bold),
                             ),
                           ],
                         ),
                         const SizedBox(height: 8),
                         Text(
                           state.inputText!.length > 200
                               ? '${state.inputText!.substring(0, 200)}...'
                               : state.inputText!,
                           style: const TextStyle(fontSize: 14),
                         ),
                         if (state.inputText!.length > 200) ...[
                           const SizedBox(height: 4),
                           Text(
                             '(${state.inputText!.length} caractères au total)',
                             style: TextStyle(
                               fontSize: 12,
                               color: Colors.grey.shade600,
                             ),
                           ),
                         ],
                       ],
                     ),
                   ),
                 ),
               ],

               // Download widget and reset button
               if (state.audioFile != null) ...[
                 const SizedBox(height: 20),
                 Card(
                   color: Theme.of(context).colorScheme.tertiaryContainer,
                   child: Padding(
                     padding: const EdgeInsets.all(16.0),
                     child: Column(
                       children: [
                         Icon(Icons.check_circle, color: Theme.of(context).colorScheme.onTertiaryContainer, size: 48),
                         const SizedBox(height: 8),
                         Text(
                           'Audio généré avec succès !',
                           style: TextStyle(
                             fontWeight: FontWeight.bold,
                             color: Theme.of(context).colorScheme.onTertiaryContainer,
                           ),
                         ),
                       ],
                     ),
                   ),
                 ),
                 const SizedBox(height: 10),
                 DownloadWidget(file: state.audioFile!),
                 const SizedBox(height: 10),
                 ElevatedButton(
                   onPressed: () => ref.read(ttsProvider.notifier).reset(),
                   child: const Text("Recommencer"),
                 )
               ]
            ],
          ),
        ),
      ),
    );
  }

  /// Get helpful suggestion based on error message
  String? _getSuggestion(String errorMessage) {
    if (errorMessage.contains('quota exceeded') || errorMessage.contains('Quota')) {
      return '💡 Astuce : Les quotas gratuits se réinitialisent chaque mois.';
    }
    if (errorMessage.contains('API key') || errorMessage.contains('not enabled')) {
      return '💡 Astuce : Vérifiez que votre clé API est configurée dans le fichier .env et que l\'API Text-to-Speech est activée dans Google Cloud Console.';
    }
    if (errorMessage.contains('vide')) {
      return '💡 Astuce : Assurez-vous que votre fichier .txt contient du texte.';
    }
    if (errorMessage.contains('timeout') || errorMessage.contains('timed out')) {
      return '💡 Astuce : Vérifiez votre connexion internet et réessayez.';
    }
    return null;
  }
}
