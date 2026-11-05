import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/db/database.dart';
import 'core/sync/supabase_client.dart';
import 'core/sync/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Phase F-1: Cloud sync configuration gate moved below database initialization in F-4a-1.

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(1024, 680),
      minimumSize: Size(1024, 680),
      center: true,
      title: "Ailyans School Automation System",
      titleBarStyle: TitleBarStyle.normal,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.maximize();
      await windowManager.focus();
    });
  }

  // Block on database initialization and schema migration
  await DatabaseService.instance.database;

  if (const bool.fromEnvironment('CLOUD_SYNC_CONFIGURED', defaultValue: true)) {
    SupabaseClientWrapper.init().then((_) => SyncService.runStartupPush());
  }

  runApp(const ProviderScope(child: AilyansApp()));
}
