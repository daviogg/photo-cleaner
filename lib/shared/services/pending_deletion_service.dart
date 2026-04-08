import 'package:hive/hive.dart';

class PendingDeletionService {
  PendingDeletionService(this._box);

  final Box<int> _box;

  static const boxName = 'pending_deletions';

  static Future<PendingDeletionService> create() async {
    final box = await Hive.openBox<int>(boxName);
    return PendingDeletionService(box);
  }

  Map<String, int> get dueByAssetId => Map<String, int>.from(_box.toMap());

  Future<void> markPending({
    required String assetId,
    required DateTime dueAt,
  }) async {
    await _box.put(assetId, dueAt.millisecondsSinceEpoch);
  }

  Future<void> unmarkPending(String assetId) async {
    await _box.delete(assetId);
  }
}

