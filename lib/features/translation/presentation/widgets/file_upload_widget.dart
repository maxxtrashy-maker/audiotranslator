import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class FileUploadWidget extends StatelessWidget {
  final Function(File) onFileSelected;
  final List<String>? acceptedExtensions;
  final String? buttonText;

  const FileUploadWidget({
    super.key,
    required this.onFileSelected,
    this.acceptedExtensions,
    this.buttonText,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton.icon(
        icon: const Icon(Icons.upload_file),
        label: Text(buttonText ?? 'Sélectionner un fichier'),
        onPressed: () async {
          FilePickerResult? result = await FilePicker.platform.pickFiles(
            type: acceptedExtensions != null ? FileType.custom : FileType.any,
            allowedExtensions: acceptedExtensions,
          );

          if (result != null && result.files.single.path != null) {
            onFileSelected(File(result.files.single.path!));
          }
        },
      ),
    );
  }
}
