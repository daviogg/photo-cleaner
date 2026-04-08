import 'package:photoswipe/shared/models/swipe_action.dart';

class SwipeRecord {
  const SwipeRecord({
    required this.assetId,
    required this.action,
  });

  final String assetId;
  final SwipeAction action;
}

