import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photoswipe/features/gallery_access/gallery_permission_controller.dart';

class PermissionScreen extends ConsumerWidget {
  const PermissionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissionAsync = ref.watch(galleryPermissionControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PhotoSwipe'),
      ),
      body: SafeArea(
        child: permissionAsync.when(
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (e, st) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error reading permission state.\n$e'),
            ),
          ),
          data: (state) {
            final controller = ref.read(galleryPermissionControllerProvider.notifier);
            final title = switch (state.level) {
              GalleryAccessLevel.full => 'Full Photo Access Granted',
              GalleryAccessLevel.limited => 'Limited Photo Access',
              GalleryAccessLevel.none => 'Photo Access Needed',
            };

            final subtitle = switch (state.level) {
              GalleryAccessLevel.full =>
                'You can start swiping. Photos are loaded locally from your library.',
              GalleryAccessLevel.limited =>
                'You granted access to selected photos only. You can continue, or select more photos.',
              GalleryAccessLevel.none =>
                'To review your photos, PhotoSwipe needs access to your photo library.',
            };

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(subtitle),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: controller.request,
                      child: const Text('Request Photo Permission'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (state.level == GalleryAccessLevel.limited) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: controller.manageLimitedSelection,
                        child: const Text('Select More Photos'),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: controller.openSettings,
                      child: const Text('Open iOS Settings'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: controller.refresh,
                      child: const Text('Refresh'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

