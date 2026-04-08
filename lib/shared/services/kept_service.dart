import 'package:hive/hive.dart';
import 'package:photoswipe/shared/services/hive_boxes.dart';

class KeptService {
  KeptService(this._box);

  final Box<String> _box;

  static Future<KeptService> create() async {
    final box = await Hive.openBox<String>(HiveBoxes.kept);
    return KeptService(box);
  }

  List<String> get ids => _box.values.toList(growable: false);

  bool isKept(String assetId) => _box.containsKey(assetId);

  Future<void> keep(String assetId) async {
    await _box.put(assetId, assetId);
  }

  Future<void> unkeep(String assetId) async {
    await _box.delete(assetId);
  }
}

