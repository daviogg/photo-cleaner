import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:photoswipe/features/favorites/favorites_screen.dart';
import 'package:photoswipe/features/swipe_review/swipe_controller.dart';
import 'package:photoswipe/shared/models/swipe_action.dart';

class SwipeScreen extends ConsumerStatefulWidget {
  const SwipeScreen({super.key});

  @override
  ConsumerState<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends ConsumerState<SwipeScreen> {
  final _swiperController = CardSwiperController();

  @override
  void dispose() {
    _swiperController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final swipeAsync = ref.watch(swipeControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PhotoSwipe'),
        actions: [
          IconButton(
            tooltip: 'Undo',
            onPressed: () async {
              final ok = await ref.read(swipeControllerProvider.notifier).undoLast();
              if (ok) {
                _swiperController.undo();
              }
            },
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: 'Favorites',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FavoritesScreen()),
              );
            },
            icon: const Icon(Icons.favorite_border),
          ),
        ],
      ),
      body: SafeArea(
        child: swipeAsync.when(
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (e, st) => Center(child: Text('Error loading photos.\n$e')),
          data: (state) {
            if (state.assets.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No photos found (or none accessible in limited mode).'),
                ),
              );
            }

            return Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: CardSwiper(
                      controller: _swiperController,
                      cardsCount: state.assets.length,
                      numberOfCardsDisplayed: 3,
                      isLoop: false,
                      allowedSwipeDirection: const AllowedSwipeDirection.only(
                        left: true,
                        right: true,
                        up: true,
                        down: false,
                      ),
                      onSwipe: (previousIndex, currentIndex, direction) async {
                        final action = _mapDirection(direction);
                        if (action == null) return true;

                        await ref.read(swipeControllerProvider.notifier).onSwiped(
                              swipedIndex: previousIndex,
                              action: action,
                              nextIndexHint: currentIndex ?? previousIndex + 1,
                            );

                        if (!context.mounted) return true;
                        if (action == SwipeAction.delete) {
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Deleting in 7 seconds…'),
                              action: SnackBarAction(
                                label: 'UNDO',
                                onPressed: () async {
                                  final ok = await ref
                                      .read(swipeControllerProvider.notifier)
                                      .undoLast();
                                  if (ok) {
                                    _swiperController.undo();
                                  }
                                },
                              ),
                              duration: const Duration(seconds: 7),
                            ),
                          );
                        }
                        return true;
                      },
                      cardBuilder: (context, index, percentThresholdX, percentThresholdY) {
                        final asset = state.assets[index];
                        return _PhotoCard(asset: asset);
                      },
                    ),
                  ),
                ),
                _SwipeHintBar(
                  onKeep: () => _swiperController.swipe(CardSwiperDirection.right),
                  onDelete: () => _swiperController.swipe(CardSwiperDirection.left),
                  onFavorite: () => _swiperController.swipe(CardSwiperDirection.top),
                ),
                const SizedBox(height: 10),
              ],
            );
          },
        ),
      ),
    );
  }

  SwipeAction? _mapDirection(CardSwiperDirection direction) {
    return switch (direction) {
      CardSwiperDirection.left => SwipeAction.delete,
      CardSwiperDirection.right => SwipeAction.keep,
      CardSwiperDirection.top => SwipeAction.favorite,
      _ => null,
    };
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({required this.asset});

  final AssetEntity asset;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Colors.black),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AssetEntityImage(
              asset,
              isOriginal: false,
              thumbnailSize: const ThumbnailSize(900, 900),
              fit: BoxFit.cover,
              filterQuality: FilterQuality.low,
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text(
                      _formatMeta(asset),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatMeta(AssetEntity asset) {
    final date = asset.createDateTime;
    final w = asset.width;
    final h = asset.height;
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} • ${w}×$h';
  }
}

class _SwipeHintBar extends StatelessWidget {
  const _SwipeHintBar({
    required this.onDelete,
    required this.onKeep,
    required this.onFavorite,
  });

  final VoidCallback onDelete;
  final VoidCallback onKeep;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _RoundActionButton(
          onPressed: onDelete,
          icon: Icons.close,
          label: 'Delete',
          color: Colors.red,
        ),
        _RoundActionButton(
          onPressed: onFavorite,
          icon: Icons.star,
          label: 'Fav',
          color: Colors.orange,
        ),
        _RoundActionButton(
          onPressed: onKeep,
          icon: Icons.check,
          label: 'Keep',
          color: Colors.green,
        ),
      ],
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  const _RoundActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.color,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filled(
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: color.withValues(alpha: 0.15),
            foregroundColor: color,
            minimumSize: const Size(60, 60),
          ),
          icon: Icon(icon),
        ),
        const SizedBox(height: 4),
        Text(label),
      ],
    );
  }
}

