import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photoswipe/features/swipe_review/swipe_screen.dart';
import 'package:photoswipe/shared/widgets/permission_gate.dart';

void main() {
  runApp(const ProviderScope(child: PhotoSwipeApp()));
}

class PhotoSwipeApp extends StatelessWidget {
  const PhotoSwipeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PhotoSwipe',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: PermissionGate(
        authorizedBuilder: (_) => const SwipeScreen(),
      ),
    );
  }
}
