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
      title: "ByteWave School Automation",
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      darkTheme: appDarkTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
      // G-10 Shot 11b-2: clamp OS text scaling to a safe range so buttons,
      // pills, and step labels on small Android phones (320-360px width) or
      // with "Large"/"Largest" system font settings never clip their text.
      // 0.85 keeps accessibility scaling usable; 1.10 is the largest factor
      // every compact control in the app is verified against.
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final currentScale = mediaQuery.textScaler.scale(1.0);
        final clampedScale = currentScale.clamp(0.85, 1.10);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(clampedScale),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
