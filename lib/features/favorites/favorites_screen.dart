import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:photoswipe/shared/services/service_providers.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favAsync = ref.watch(favoritesServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
      ),
      body: SafeArea(
        child: favAsync.when(
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (e, st) => Center(child: Text('Error loading favorites.\n$e')),
          data: (favorites) {
            return FutureBuilder<List<AssetEntity>>(
              future: _resolveAssets(favorites.ids),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CupertinoActivityIndicator());
                }
                final assets = snapshot.data!;
                if (assets.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No favorites yet. Swipe up to favorite.'),
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: assets.length,
                  itemBuilder: (context, index) {
                    final asset = assets[index];
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          AssetEntityImage(
                            asset,
                            isOriginal: false,
                            thumbnailSize: const ThumbnailSize(260, 260),
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.low,
                          ),
                          Align(
                            alignment: Alignment.topRight,
                            child: IconButton(
                              tooltip: 'Remove favorite',
                              onPressed: () async {
                                await favorites.remove(asset.id);
                                ref.invalidate(favoritesServiceProvider);
                              },
                              icon: const Icon(Icons.close, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<List<AssetEntity>> _resolveAssets(List<String> ids) async {
    final futures = ids.map(AssetEntity.fromId);
    final resolved = await Future.wait(futures);
    return resolved.whereType<AssetEntity>().toList(growable: false);
  }
}

