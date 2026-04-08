import 'package:hive/hive.dart';
import 'package:photoswipe/shared/services/hive_boxes.dart';

class FavoritesService {
  FavoritesService(this._box);

  final Box<String> _box;

  static Future<FavoritesService> create() async {
    final box = await Hive.openBox<String>(HiveBoxes.favorites);
    return FavoritesService(box);
  }

  List<String> get ids => _box.values.toList(growable: false);

  bool isFavorite(String assetId) => _box.containsKey(assetId);

  Future<void> add(String assetId) async {
    await _box.put(assetId, assetId);
  }

  Future<void> remove(String assetId) async {
    await _box.delete(assetId);
  }
}

