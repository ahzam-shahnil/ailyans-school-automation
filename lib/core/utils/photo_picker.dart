import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

/// Canonical photo picker with the legacy 50 KB validation gate.
/// Returns the picked source-file path, or null if user cancelled,
/// file too large, or picker failed.
Future<String?> pickPhotoWithValidation(BuildContext context) async {
  try {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
    );
    if (files.isEmpty || files.first.path == null) return null;
    final path = files.first.path!;
    final sizeBytes = await File(path).length();
    if (sizeBytes > 50 * 1024) {
      final sizeKb = (sizeBytes / 1024).toStringAsFixed(2);
      if (!context.mounted) return null;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Picture Size Error'),
          content: Text(
            'Picture Size is $sizeKb KB. It Must be Less then 50 KB',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return null;
    }
    return path;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Photo picker failed: $e')));
    }
    return null;
  }
}
