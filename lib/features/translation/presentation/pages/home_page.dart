import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/language_mapper.dart';
import '../providers/translation_provider.dart';
import '../widgets/file_upload_widget.dart';
import '../widgets/progress_widget.dart';
import '../widgets/download_widget.dart';
import '../widgets/language_selector_widget.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(translationProvider);
    final isAudioMode = state.inputMode == InputMode.audioFile;

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
              if (!state.isLoading && state.outputAudioFile == null)
                _buildModeToggle(context, ref, state),

              const SizedBox(height: 12),

              // Language selectors
              if (!state.isLoading && state.outputAudioFile == null) ...[
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
              if (!state.isLoading && state.outputAudioFile == null)
                _buildInstructions(context, isAudioMode),

              const SizedBox(height: 20),

              // File upload button
              if (!state.isLoading && state.outputAudioFile == null)
                FileUploadWidget(
                  onFileSelected: (file) {
                    if (isAudioMode) {
                      ref.read(translationProvider.notifier).processAudioFile(file);
                    } else {
                      ref.read(translationProvider.notifier).processTextFile(file);
                    }
                  },
                  acceptedExtensions: isAudioMode
                      ? const ['m4a', 'mp3', 'wav', 'flac', 'ogg']
                      : const ['txt'],
                  buttonText: isAudioMode
                      ? 'S\u00e9lectionner un fichier audio'
                      : 'S\u00e9lectionner un fichier texte (.txt)',
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

              // Transcription result
              if (state.transcribedText != null) ...[
                const SizedBox(height: 20),
                _buildResultCard(
                  context,
                  icon: Icons.mic,
                  title: 'Transcription :',
                  text: state.transcribedText!,
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
              ],

              // Input text preview (text mode only)
              if (state.inputText != null &&
                  !isAudioMode &&
                  state.transcribedText == null) ...[
                const SizedBox(height: 20),
                _buildResultCard(
                  context,
                  icon: Icons.text_fields,
                  title: 'Texte \u00e0 synth\u00e9tiser :',
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
                          'Audio g\u00e9n\u00e9r\u00e9 avec succ\u00e8s !',
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

  Widget _buildModeToggle(
      BuildContext context, WidgetRef ref, TranslationState state) {
    return SegmentedButton<InputMode>(
      segments: const [
        ButtonSegment(
          value: InputMode.audioFile,
          label: Text('Fichier audio'),
          icon: Icon(Icons.audiotrack),
        ),
        ButtonSegment(
          value: InputMode.textFile,
          label: Text('Fichier texte'),
          icon: Icon(Icons.description),
        ),
      ],
      selected: {state.inputMode},
      onSelectionChanged: (Set<InputMode> selected) {
        ref.read(translationProvider.notifier).setInputMode(selected.first);
      },
    );
  }

  Widget _buildInstructions(BuildContext context, bool isAudioMode) {
    final text = isAudioMode
        ? '1. S\u00e9lectionnez la langue source (ou Auto-detect)\n'
            '2. S\u00e9lectionnez la langue cible\n'
            '3. Uploadez un fichier audio (m4a, mp3, wav...)\n'
            '4. L\u0027application transcrira, traduira et g\u00e9n\u00e8rera l\u0027audio'
        : '1. S\u00e9lectionnez la langue de synth\u00e8se vocale\n'
            '2. Uploadez un fichier .txt contenant votre texte\n'
            '3. L\u0027application g\u00e9n\u00e9rera un fichier audio WAV';

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
                '(${text.length} caract\u00e8res au total)',
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
      return 'Astuce : Les quotas gratuits se r\u00e9initialisent chaque mois.';
    }
    if (errorMessage.contains('API') && errorMessage.contains('invalide')) {
      return 'Astuce : V\u00e9rifiez que vos cl\u00e9s API sont configur\u00e9es dans le fichier .env.';
    }
    if (errorMessage.contains('vide')) {
      return 'Astuce : Assurez-vous que votre fichier contient du contenu.';
    }
    if (errorMessage.contains('timeout') ||
        errorMessage.contains('d\u00e9lai')) {
      return 'Astuce : V\u00e9rifiez votre connexion internet et r\u00e9essayez.';
    }
    if (errorMessage.contains('25 Mo') ||
        errorMessage.contains('volumineux')) {
      return 'Astuce : Le fichier audio ne doit pas d\u00e9passer 25 Mo.';
    }
    return null;
  }
}
