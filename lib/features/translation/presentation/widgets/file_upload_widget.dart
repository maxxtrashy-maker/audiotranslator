import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class FileUploadWidget extends StatelessWidget {
  final Function(File) onFileSelected;

  const FileUploadWidget({super.key, required this.onFileSelected});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton.icon(
        icon: const Icon(Icons.upload_file),
        label: const Text('Sélectionner un fichier audio'),
        onPressed: () async {
          FilePickerResult? result = await FilePicker.platform.pickFiles(
            type: FileType.audio,
             // allowMultiple: false
          );

          if (result != null && result.files.single.path != null) {
            onFileSelected(File(result.files.single.path!));
          }
        },
      ),
    );
  }
}
