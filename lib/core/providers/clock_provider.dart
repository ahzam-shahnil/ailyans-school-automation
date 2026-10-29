import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides the current date/time.
///
/// Production: reads real system clock.
/// Tests: override with a fixed DateTime for deterministic assertions.
///
/// USAGE:  ref.read(clockProvider)()
/// NEVER:  DateTime.now() directly in lib/
final clockProvider = Provider<DateTime Function()>((ref) {
  return () => DateTime.now();
});
