import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/language_mapper.dart';
import '../providers/translation_provider.dart';

class LanguageSelectorWidget extends ConsumerWidget {
  final bool isSource;
  final List<String>? languages;

  const LanguageSelectorWidget({
    super.key,
    this.isSource = false,
    this.languages,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(translationProvider);

    final languageList = languages ??
        (isSource
            ? LanguageMapper.sourceLanguages
            : LanguageMapper.supportedTargetLanguages);

    final currentValue = isSource ? state.sourceLanguage : state.targetLanguage;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isSource ? 'Langue source :' : 'Langue cible :',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButton<String>(
              value: currentValue,
              isExpanded: true,
              items: languageList.map((String language) {
                return DropdownMenuItem<String>(
                  value: language,
                  child: Text(LanguageMapper.getLabel(language)),
                );
              }).toList(),
              onChanged: state.isLoading
                  ? null
                  : (String? newValue) {
                      if (newValue != null) {
                        if (isSource) {
                          ref
                              .read(translationProvider.notifier)
                              .setSourceLanguage(newValue);
                        } else {
                          ref
                              .read(translationProvider.notifier)
                              .setTargetLanguage(newValue);
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}
