import 'package:hive/hive.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photoswipe/shared/services/hive_boxes.dart';

class DeleteQueueService {
  DeleteQueueService(this._box);

  final Box<String> _box;

  static Future<DeleteQueueService> create() async {
    final box = await Hive.openBox<String>(HiveBoxes.deleteQueue);
    return DeleteQueueService(box);
  }

  List<String> get ids => _box.values.toList(growable: false);

  bool contains(String assetId) => _box.containsKey(assetId);

  Future<void> enqueue(String assetId) async {
    await _box.put(assetId, assetId);
  }

  Future<void> dequeue(String assetId) async {
    await _box.delete(assetId);
  }

  Future<void> clear() async {
    await _box.clear();
  }

  Future<bool> deleteAllFromDevice() async {
    final idsToDelete = ids;
    if (idsToDelete.isEmpty) return true;

    final failedIds = await PhotoManager.editor.deleteWithIds(idsToDelete);
    final ok = failedIds.isEmpty;
    if (ok) {
      await clear();
    }
    return ok;
  }
}

