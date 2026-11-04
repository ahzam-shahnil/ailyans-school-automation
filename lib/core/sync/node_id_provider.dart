import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:school_automation/core/sync/node_id_allocator.dart';

final nodeIdAllocatorProvider = Provider<NodeIdAllocator>((ref) {
  return NodeIdAllocator();
});
