import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

/// Canonical photo picker.
/// Returns the picked source-file path, or null if user cancelled or picker failed.
Future<String?> pickPhotoWithValidation(BuildContext context) async {
  try {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
    );
    if (files.isEmpty || files.first.path == null) return null;
    return files.first.path;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Photo picker failed: $e')));
    }
    return null;
  }
}
