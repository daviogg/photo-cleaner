import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photoswipe/shared/services/service_providers.dart';

enum GalleryAccessLevel {
  none,
  limited,
  full,
}

class GalleryPermissionState {
  const GalleryPermissionState({
    required this.level,
    required this.status,
  });

  final GalleryAccessLevel level;
  final PermissionStatus status;

  bool get canRead => level != GalleryAccessLevel.none;
}

final galleryPermissionControllerProvider =
    AsyncNotifierProvider<GalleryPermissionController, GalleryPermissionState>(
  GalleryPermissionController.new,
);

class GalleryPermissionController extends AsyncNotifier<GalleryPermissionState> {
  @override
  Future<GalleryPermissionState> build() async {
    final status = await Permission.photos.status;
    return _map(status);
  }

  GalleryPermissionState _map(PermissionStatus status) {
    final level = switch (status) {
      PermissionStatus.granted => GalleryAccessLevel.full,
      PermissionStatus.limited => GalleryAccessLevel.limited,
      _ => GalleryAccessLevel.none,
    };
    return GalleryPermissionState(level: level, status: status);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final status = await Permission.photos.status;
      return _map(status);
    });
  }

  Future<void> request() async {
    // Also trigger photo_manager so iOS shows the library dialog when appropriate.
    final photoService = ref.read(photoServiceProvider);
    await photoService.requestPermission();

    state = await AsyncValue.guard(() async {
      final status = await Permission.photos.request();
      return _map(status);
    });
  }

  Future<void> openSettings() async {
    await openAppSettings();
    await refresh();
  }

  Future<void> manageLimitedSelection() async {
    // Shows Apple's "Select More Photos" UI when the app has limited access.
    final photoService = ref.read(photoServiceProvider);
    await photoService.presentLimitedPicker();
    await refresh();
  }
}

