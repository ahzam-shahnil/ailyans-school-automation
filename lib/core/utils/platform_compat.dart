import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Global test override for legacy Windows detection.
bool? debugIsLegacyWindowsOverride;

/// Detects legacy Windows versions (Windows 7, 8, 8.1, Server 2012) where the
/// native Windows PDF rasterization APIs and modern Share contracts are missing,
/// causing native crashes (0xc0000409 fastfail in `Printing` / `PdfPreview`).
///
/// Windows 10 (kernel 10.0+) and newer, as well as non-Windows OSes, return false.
bool isLegacyWindows({String? versionOverride, bool? isWindowsOverride}) {
  if (versionOverride != null || isWindowsOverride != null) {
    final isWin = isWindowsOverride ?? Platform.isWindows;
    if (!isWin) return false;
    final v = versionOverride ?? Platform.operatingSystemVersion;
    // Strip quoted marketing name (e.g. '"Windows 8.1 Pro"') so regex anchors on kernel version '6.3'
    final s = v.replaceAll(RegExp(r'"[^"]*"'), '');
    final m = RegExp(r'\b(\d+)\.(\d+)(?:\.(\d+))?\b').firstMatch(s);
    if (m == null) return false;
    return int.parse(m.group(1)!) < 10; // 6.x = Win7/8/8.1 legacy; 10.x+ = supported
  }
  if (debugIsLegacyWindowsOverride != null) {
    return debugIsLegacyWindowsOverride!;
  }
  final isWin = Platform.isWindows;
  if (!isWin) return false;
  final v = Platform.operatingSystemVersion;
  final s = v.replaceAll(RegExp(r'"[^"]*"'), '');
  final m = RegExp(r'\b(\d+)\.(\d+)(?:\.(\d+))?\b').firstMatch(s);
  if (m == null) return false;
  return int.parse(m.group(1)!) < 10;
}

/// Safely writes [bytes] to a temporary `.pdf` file and launches the host OS's
/// default external PDF viewer (e.g. Acrobat Reader, SumatraPDF, Edge).
///
/// Used on legacy Windows (7/8/8.1) where in-app rasterization crashes.
Future<bool> openPdfExternal({
  required Uint8List bytes,
  required String fileName,
}) async {
  try {
    Directory tempDir;
    try {
      tempDir = await getTemporaryDirectory();
    } catch (_) {
      tempDir = Directory.systemTemp;
    }
    final safeName = fileName.endsWith('.pdf') ? fileName : '$fileName.pdf';
    final file = File(p.join(tempDir.path, safeName));
    await file.writeAsBytes(bytes, flush: true);
    return await launchUrl(
      Uri.file(file.path),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}
