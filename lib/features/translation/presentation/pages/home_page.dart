import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/utils/language_mapper.dart';
import '../providers/translation_provider.dart';
import '../widgets/file_upload_widget.dart';
import '../widgets/progress_widget.dart';
import '../widgets/download_widget.dart';
import '../widgets/language_selector_widget.dart';
import '../widgets/youtube_url_input_widget.dart';
import '../widgets/transcript_result_widget.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(translationProvider);
    final isAudioMode = state.inputMode == InputMode.audioFile;
    final isYouTubeMode = state.inputMode == InputMode.youTube;
    final isYouTubeCompleted = isYouTubeMode &&
        state.transcribedText != null &&
        !state.isLoading;

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
                _buildErrorCard(context, state.errorMessage!),

              // Mode toggle
              if (!state.isLoading &&
                  state.outputAudioFile == null &&
                  !isYouTubeCompleted)
                _buildModeToggle(context, ref, state),

              const SizedBox(height: 12),

              // Language selectors (hidden in YouTube mode)
              if (!state.isLoading &&
                  state.outputAudioFile == null &&
                  !isYouTubeMode) ...[
                if (isAudioMode)
                  const LanguageSelectorWidget(isSource: true),
                LanguageSelectorWidget(
                  isSource: false,
                  languages: isAudioMode
                      ? LanguageMapper.pipelineTargetLanguages
                      : LanguageMapper.supportedTargetLanguages,
                ),
                const SizedBox(height: 12),
              ],

              // Instructions
              if (!state.isLoading &&
                  state.outputAudioFile == null &&
                  !isYouTubeCompleted)
                _buildInstructions(context, state.inputMode),

              const SizedBox(height: 20),

              // YouTube URL input
              if (isYouTubeMode &&
                  !state.isLoading &&
                  !isYouTubeCompleted)
                YouTubeUrlInputWidget(
                  onExtract: (videoId) {
                    ref
                        .read(translationProvider.notifier)
                        .processYouTubeUrl(videoId);
                  },
                ),

              // File upload button (audio & text modes)
              if (!isYouTubeMode &&
                  !state.isLoading &&
                  state.outputAudioFile == null)
                FileUploadWidget(
                  onFileSelected: (file) {
                    if (isAudioMode) {
                      ref
                          .read(translationProvider.notifier)
                          .processAudioFile(file);
                    } else {
                      ref
                          .read(translationProvider.notifier)
                          .processTextFile(file);
                    }
                  },
                  acceptedExtensions: isAudioMode
                      ? const ['m4a', 'mp3', 'wav', 'flac', 'ogg']
                      : const ['txt'],
                  buttonText: isAudioMode
                      ? 'Sélectionner un fichier audio'
                      : 'Sélectionner un fichier texte (.txt)',
                ),

              // Progress
              if (state.isLoading) ...[
                ProgressWidget(
                  progress: state.progress,
                  currentStep: isAudioMode ? state.currentStep : null,
                ),
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

              // YouTube transcript result
              if (isYouTubeCompleted)
                TranscriptResultWidget(
                  transcript: state.transcribedText!,
                  savedFile: state.savedTextFiles.isNotEmpty
                      ? state.savedTextFiles.first
                      : null,
                  onNewExtraction: () =>
                      ref.read(translationProvider.notifier).reset(),
                ),

              // Transcription result (audio mode)
              if (state.transcribedText != null && !isYouTubeMode) ...[
                const SizedBox(height: 20),
                _buildResultCard(
                  context,
                  icon: Icons.mic,
                  title: 'Transcription :',
                  text: state.transcribedText!,
                ),
                if (state.savedTextFiles.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton.icon(
                      onPressed: () => _shareFile(state.savedTextFiles[0]),
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('Partager la transcription .txt'),
                    ),
                  ),
              ],

              // Translation result
              if (state.translatedText != null) ...[
                const SizedBox(height: 12),
                _buildResultCard(
                  context,
                  icon: Icons.translate,
                  title: 'Traduction :',
                  text: state.translatedText!,
                ),
                if (state.savedTextFiles.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton.icon(
                      onPressed: () => _shareFile(state.savedTextFiles[1]),
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('Partager la traduction .txt'),
                    ),
                  ),
              ],

              // Input text preview (text mode only)
              if (state.inputText != null &&
                  !isAudioMode &&
                  !isYouTubeMode &&
                  state.transcribedText == null) ...[
                const SizedBox(height: 20),
                _buildResultCard(
                  context,
                  icon: Icons.text_fields,
                  title: 'Texte à synthétiser :',
                  text: state.inputText!,
                ),
              ],

              // Success + download
              if (state.outputAudioFile != null) ...[
                const SizedBox(height: 20),
                Card(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Icon(Icons.check_circle,
                            color: Theme.of(context)
                                .colorScheme
                                .onTertiaryContainer,
                            size: 48),
                        const SizedBox(height: 8),
                        Text(
                          'Audio généré avec succès !',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .colorScheme
                                .onTertiaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                DownloadWidget(file: state.outputAudioFile!),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () =>
                      ref.read(translationProvider.notifier).reset(),
                  child: const Text("Recommencer"),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareFile(File file) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)]),
    );
  }

  Widget _buildModeToggle(
      BuildContext context, WidgetRef ref, TranslationState state) {
    return SegmentedButton<InputMode>(
      segments: const [
        ButtonSegment(
          value: InputMode.audioFile,
          label: Text('Audio'),
          icon: Icon(Icons.audiotrack),
        ),
        ButtonSegment(
          value: InputMode.textFile,
          label: Text('Texte'),
          icon: Icon(Icons.description),
        ),
        ButtonSegment(
          value: InputMode.youTube,
          label: Text('YouTube'),
          icon: Icon(Icons.play_circle_outline),
        ),
      ],
      selected: {state.inputMode},
      onSelectionChanged: (Set<InputMode> selected) {
        ref.read(translationProvider.notifier).setInputMode(selected.first);
      },
    );
  }

  Widget _buildInstructions(BuildContext context, InputMode mode) {
    final String text;
    switch (mode) {
      case InputMode.audioFile:
        text = '1. Sélectionnez la langue source (ou Auto-detect)\n'
            '2. Sélectionnez la langue cible\n'
            '3. Uploadez un fichier audio (m4a, mp3, wav...)\n'
            '4. L\'application transcrira, traduira et génèrera l\'audio';
        break;
      case InputMode.textFile:
        text = '1. Sélectionnez la langue de synthèse vocale\n'
            '2. Uploadez un fichier .txt contenant votre texte\n'
            '3. L\'application générera un fichier audio WAV';
        break;
      case InputMode.youTube:
        text = '1. Collez l\'URL d\'une vidéo YouTube\n'
            '2. L\'application extraira les sous-titres automatiquement\n'
            '3. Copiez le texte extrait';
        break;
    }

    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline,
                    color: Theme.of(context).colorScheme.onPrimaryContainer),
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
              text,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String text,
  }) {
    final displayText =
        text.length > 300 ? '${text.substring(0, 300)}...' : text;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(displayText, style: const TextStyle(fontSize: 14)),
            if (text.length > 300) ...[
              const SizedBox(height: 4),
              Text(
                '(${text.length} caractères au total)',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, String errorMessage) {
    return Container(
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
              Icon(Icons.error_outline,
                  color: Theme.of(context).colorScheme.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  errorMessage,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (_getSuggestion(errorMessage) != null) ...[
            const SizedBox(height: 8),
            Text(
              _getSuggestion(errorMessage)!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? _getSuggestion(String errorMessage) {
    if (errorMessage.contains('quota') || errorMessage.contains('Quota')) {
      return 'Astuce : Les quotas gratuits se réinitialisent chaque mois.';
    }
    if (errorMessage.contains('API') && errorMessage.contains('invalide')) {
      return 'Astuce : Vérifiez que vos clés API sont configurées dans le fichier .env.';
    }
    if (errorMessage.contains('vide')) {
      return 'Astuce : Assurez-vous que votre fichier contient du contenu.';
    }
    if (errorMessage.contains('timeout') ||
        errorMessage.contains('délai')) {
      return 'Astuce : Vérifiez votre connexion internet et réessayez.';
    }
    if (errorMessage.contains('25 Mo') ||
        errorMessage.contains('volumineux')) {
      return 'Astuce : Le fichier audio ne doit pas dépasser 25 Mo.';
    }
    if (errorMessage.contains('sous-titre') ||
        errorMessage.contains('publique')) {
      return 'Astuce : Vérifiez que la vidéo est publique et possède des sous-titres activés.';
    }
    if (errorMessage.contains('YouTube') ||
        errorMessage.contains('vidéo')) {
      return 'Astuce : Vérifiez l\'URL et que la vidéo est accessible.';
    }
    return null;
  }
}
