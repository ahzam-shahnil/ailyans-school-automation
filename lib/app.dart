import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme_tokens.dart';

/// Root application widget for Ailyans School Automation System.
class AilyansApp extends ConsumerWidget {
  const AilyansApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: "Ailyans School Automation System",
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      darkTheme: appDarkTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
