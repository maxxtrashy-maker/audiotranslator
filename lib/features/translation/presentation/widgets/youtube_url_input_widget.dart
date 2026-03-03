import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/utils/youtube_url_parser.dart';

class YouTubeUrlInputWidget extends StatefulWidget {
  final void Function(String videoId) onExtract;

  const YouTubeUrlInputWidget({super.key, required this.onExtract});

  @override
  State<YouTubeUrlInputWidget> createState() => _YouTubeUrlInputWidgetState();
}

class _YouTubeUrlInputWidgetState extends State<YouTubeUrlInputWidget> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _controller.text = data!.text!;
      _formKey.currentState?.validate();
    }
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final videoId = YouTubeUrlParser.extractVideoId(_controller.text);
      if (videoId != null) {
        widget.onExtract(videoId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: 'URL YouTube',
              hintText: 'https://www.youtube.com/watch?v=...',
              prefixIcon: const Icon(Icons.link),
              suffixIcon: IconButton(
                icon: const Icon(Icons.content_paste),
                tooltip: 'Coller',
                onPressed: _pasteFromClipboard,
              ),
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Veuillez entrer une URL YouTube';
              }
              if (!YouTubeUrlParser.isValidYouTubeUrl(value)) {
                return 'URL YouTube invalide';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.subtitles),
            label: const Text('Extraire les sous-titres'),
          ),
        ],
      ),
    );
  }
}
