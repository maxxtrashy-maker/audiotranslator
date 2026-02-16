import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/translation_provider.dart';

class LanguageSelectorWidget extends ConsumerWidget {
  const LanguageSelectorWidget({super.key});

  static const List<String> supportedLanguages = [
    'French',
    'English',
    'Spanish',
    'German',
    'Italian',
    'Portuguese',
    'Japanese',
    'Chinese',
    'Korean',
    'Arabic',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ttsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Langue de synthèse vocale :',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButton<String>(
              value: state.targetLanguage,
              isExpanded: true,
              items: supportedLanguages.map((String language) {
                return DropdownMenuItem<String>(
                  value: language,
                  child: Text(_getLanguageLabel(language)),
                );
              }).toList(),
              onChanged: state.isLoading
                  ? null
                  : (String? newValue) {
                      if (newValue != null) {
                        ref
                            .read(ttsProvider.notifier)
                            .setTargetLanguage(newValue);
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  String _getLanguageLabel(String language) {
    final labels = {
      'French': '🇫🇷 Français',
      'English': '🇬🇧 English',
      'Spanish': '🇪🇸 Español',
      'German': '🇩🇪 Deutsch',
      'Italian': '🇮🇹 Italiano',
      'Portuguese': '🇵🇹 Português',
      'Japanese': '🇯🇵 日本語',
      'Chinese': '🇨🇳 中文',
      'Korean': '🇰🇷 한국어',
      'Arabic': '🇸🇦 العربية',
    };
    
    return labels[language] ?? language;
  }
}
