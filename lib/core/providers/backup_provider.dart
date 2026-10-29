import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../db/backup_service.dart';

class BackupState {
  final bool isExporting;
  final bool isRestoring;
  final String? lastExportPath;
  final String? lastRestorePath;
  final String? errorMessage;
  final String? infoMessage;
  final List<String> availableBackups; // basenames

  const BackupState({
    this.isExporting = false,
    this.isRestoring = false,
    this.lastExportPath,
    this.lastRestorePath,
    this.errorMessage,
    this.infoMessage,
    this.availableBackups = const [],
  });

  BackupState copyWith({
    bool? isExporting,
    bool? isRestoring,
    String? lastExportPath,
    String? lastRestorePath,
    String? Function()? errorMessage,
    String? Function()? infoMessage,
    List<String>? availableBackups,
  }) {
    return BackupState(
      isExporting: isExporting ?? this.isExporting,
      isRestoring: isRestoring ?? this.isRestoring,
      lastExportPath: lastExportPath ?? this.lastExportPath,
      lastRestorePath: lastRestorePath ?? this.lastRestorePath,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      infoMessage: infoMessage != null ? infoMessage() : this.infoMessage,
      availableBackups: availableBackups ?? this.availableBackups,
    );
  }
}

class BackupNotifier extends StateNotifier<BackupState> {
  final BackupService _service;

  BackupNotifier(this._service) : super(const BackupState());

  Future<void> exportNow({String? explicitTargetPath}) async {
    state = state.copyWith(
      isExporting: true,
      errorMessage: () => null,
      infoMessage: () => null,
    );
    try {
      final file = await _service.exportSnapshot(
        explicitTargetPath: explicitTargetPath,
      );
      state = state.copyWith(
        isExporting: false,
        lastExportPath: file.path,
        infoMessage: () =>
            'Database exported successfully to ${p.basename(file.path)}',
      );
      await refreshBackupsList();
    } catch (e) {
      state = state.copyWith(
        isExporting: false,
        errorMessage: () => 'Failed to export backup: $e',
      );
    }
  }

  Future<RestoreValidation?> pickAndValidate(String pickedPath) async {
    state = state.copyWith(errorMessage: () => null, infoMessage: () => null);
    try {
      final v = await _service.validateCandidate(pickedPath);
      if (v.ok) {
        await refreshBackupsList();
      }
      return v;
    } catch (e) {
      state = state.copyWith(
        errorMessage: () => 'Failed to validate backup: $e',
      );
      return null;
    }
  }

  Future<bool> confirmRestore(String candidatePath) async {
    state = state.copyWith(
      isRestoring: true,
      errorMessage: () => null,
      infoMessage: () => null,
    );
    try {
      await _service.restoreFrom(candidatePath);
      state = state.copyWith(
        isRestoring: false,
        lastRestorePath: candidatePath,
        infoMessage: () => 'Database restored. Please log in again.',
      );
      await refreshBackupsList();
      return true;
    } catch (e) {
      state = state.copyWith(
        isRestoring: false,
        errorMessage: () => e.toString(),
      );
      return false;
    }
  }

  Future<void> runAutoBackupOnLaunch() async {
    try {
      final file = await _service.maybeAutoBackup();
      if (file != null) {
        await refreshBackupsList();
      }
    } catch (e) {
      state = state.copyWith(errorMessage: () => 'Auto-backup failed: $e');
    }
  }

  Future<void> refreshBackupsList() async {
    try {
      final files = await _service.listBackups();
      final basenames = files.map((f) => p.basename(f.path)).toList();
      state = state.copyWith(availableBackups: basenames);
    } catch (_) {}
  }

  Future<void> openBackupsFolder() async {
    await _service.openBackupsFolder();
  }

  void clearMessages() {
    state = state.copyWith(errorMessage: () => null, infoMessage: () => null);
  }
}

final backupProvider = StateNotifierProvider<BackupNotifier, BackupState>(
  (ref) => BackupNotifier(BackupService.instance),
);
