import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photoswipe/shared/models/swipe_action.dart';
import 'package:photoswipe/shared/models/swipe_record.dart';
import 'package:photoswipe/shared/services/service_providers.dart';

class SwipeState {
  const SwipeState({
    required this.assets,
    required this.page,
    required this.isLastPage,
    required this.loadingMore,
    required this.undoStack,
    required this.pendingDeleteIds,
  });

  final List<AssetEntity> assets;
  final int page;
  final bool isLastPage;
  final bool loadingMore;
  final List<SwipeRecord> undoStack;
  final Set<String> pendingDeleteIds;

  SwipeState copyWith({
    List<AssetEntity>? assets,
    int? page,
    bool? isLastPage,
    bool? loadingMore,
    List<SwipeRecord>? undoStack,
    Set<String>? pendingDeleteIds,
  }) {
    return SwipeState(
      assets: assets ?? this.assets,
      page: page ?? this.page,
      isLastPage: isLastPage ?? this.isLastPage,
      loadingMore: loadingMore ?? this.loadingMore,
      undoStack: undoStack ?? this.undoStack,
      pendingDeleteIds: pendingDeleteIds ?? this.pendingDeleteIds,
    );
  }
}

final swipeControllerProvider = AsyncNotifierProvider<SwipeController, SwipeState>(
  SwipeController.new,
);

class SwipeController extends AsyncNotifier<SwipeState> {
  static const _pageSize = 60;
  static const _deleteGracePeriod = Duration(seconds: 7);
  static const _retryDelay = Duration(seconds: 30);

  Timer? _reaper;

  @override
  Future<SwipeState> build() async {
    ref.onDispose(() {
      _reaper?.cancel();
    });

    final photoService = ref.read(photoServiceProvider);
    final first = await photoService.fetchPage(page: 0, pageSize: _pageSize);

    final pendingService = await ref.read(pendingDeletionServiceProvider.future);
    final pending = pendingService.dueByAssetId;

    // Periodically check for due deletions and batch delete them.
    _reaper ??= Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_reapDueDeletions());
    });

    return SwipeState(
      assets: first.assets,
      page: 0,
      isLastPage: first.isLastPage,
      loadingMore: false,
      undoStack: const [],
      pendingDeleteIds: pending.keys.toSet(),
    );
  }

  Future<void> _reapDueDeletions() async {
    final pendingService = await ref.read(pendingDeletionServiceProvider.future);
    final pending = pendingService.dueByAssetId;
    if (pending.isEmpty) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final dueIds = <String>[];
    for (final entry in pending.entries) {
      if (entry.value <= nowMs) {
        dueIds.add(entry.key);
      }
    }
    if (dueIds.isEmpty) return;

    // iOS Photos deletion (permanent). This will trigger a system confirmation.
    // We batch due deletions to reduce the number of prompts.
    final failedIds = await PhotoManager.editor.deleteWithIds(dueIds);
    final okIds = dueIds.where((id) => !failedIds.contains(id)).toList(growable: false);

    // Remove successful ones from pending store + in-memory state.
    for (final id in okIds) {
      await pendingService.unmarkPending(id);
    }

    // Failed ones: reschedule later (avoid tight re-prompt loops).
    if (failedIds.isNotEmpty) {
      final dueAt = DateTime.now().add(_retryDelay);
      for (final id in failedIds) {
        await pendingService.markPending(assetId: id, dueAt: dueAt);
      }
    }

    final s = state.asData?.value;
    if (s == null) return;
    final nextPending = {...s.pendingDeleteIds}..removeAll(okIds);
    state = AsyncData(s.copyWith(pendingDeleteIds: nextPending));
  }

  Future<void> _maybeLoadMore(int currentIndex) async {
    final s = state.asData?.value;
    if (s == null) return;
    if (s.isLastPage || s.loadingMore) return;

    // Prefetch when near the end.
    final remaining = s.assets.length - currentIndex - 1;
    if (remaining > 12) return;

    state = AsyncData(s.copyWith(loadingMore: true));
    state = await AsyncValue.guard(() async {
      final photoService = ref.read(photoServiceProvider);
      final nextPage = s.page + 1;
      final next = await photoService.fetchPage(page: nextPage, pageSize: _pageSize);
      return s.copyWith(
        assets: [...s.assets, ...next.assets],
        page: nextPage,
        isLastPage: next.isLastPage,
        loadingMore: false,
      );
    });
  }

  Future<void> onSwiped({
    required int swipedIndex,
    required SwipeAction action,
    required int nextIndexHint,
  }) async {
    final s = state.asData?.value;
    if (s == null) return;
    if (swipedIndex < 0 || swipedIndex >= s.assets.length) return;

    final asset = s.assets[swipedIndex];
    final record = SwipeRecord(assetId: asset.id, action: action);

    // Side-effects.
    switch (action) {
      case SwipeAction.keep:
        break;
      case SwipeAction.delete:
        final dueAt = DateTime.now().add(_deleteGracePeriod);
        final pendingService = await ref.read(pendingDeletionServiceProvider.future);
        await pendingService.markPending(assetId: asset.id, dueAt: dueAt);
        break;
      case SwipeAction.favorite:
        final favorites = await ref.read(favoritesServiceProvider.future);
        await favorites.add(asset.id);
        break;
    }

    state = AsyncData(
      s.copyWith(
        undoStack: [...s.undoStack, record],
        pendingDeleteIds: action == SwipeAction.delete
            ? {...s.pendingDeleteIds, asset.id}
            : s.pendingDeleteIds,
      ),
    );

    unawaited(_maybeLoadMore(nextIndexHint));
  }

  Future<bool> undoLast() async {
    final s = state.asData?.value;
    if (s == null) return false;
    if (s.undoStack.isEmpty) return false;

    final last = s.undoStack.last;
    switch (last.action) {
      case SwipeAction.keep:
        break;
      case SwipeAction.delete:
        final pendingService = await ref.read(pendingDeletionServiceProvider.future);
        await pendingService.unmarkPending(last.assetId);
        break;
      case SwipeAction.favorite:
        final favorites = await ref.read(favoritesServiceProvider.future);
        await favorites.remove(last.assetId);
        break;
    }

    state = AsyncData(
      s.copyWith(
        undoStack: s.undoStack.sublist(0, s.undoStack.length - 1),
        pendingDeleteIds: last.action == SwipeAction.delete
            ? ({...s.pendingDeleteIds}..remove(last.assetId))
            : s.pendingDeleteIds,
      ),
    );
    return true;
  }
}

