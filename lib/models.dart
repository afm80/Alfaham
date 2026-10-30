import 'dart:convert';
import 'dart:typed_data';

class CardItem {
  final String id;
  final String title;
  final String code;
  final String image;
  final String category;
  final bool pinned;
  final int timestamp;

  CardItem({
    required this.id,
    required this.title,
    required this.code,
    this.image = '',
    this.category = '',
    this.pinned = false,
    this.timestamp = 0,
  });

  factory CardItem.fromMap(String id, Map m) => CardItem(
        id: id,
        title: (m['title'] ?? '').toString(),
        code: (m['code'] ?? '').toString(),
        image: (m['image'] ?? '').toString(),
        category: (m['category'] ?? '').toString(),
        pinned: m['pinned'] == true,
        timestamp: m['timestamp'] is num ? (m['timestamp'] as num).toInt() : 0,
      );

  Uint8List? _bytes;
  bool _decoded = false;

  /// الصورة تُحفظ في القاعدة كنص base64، نفك ترميزها مرة واحدة فقط.
  Uint8List? get imageBytes {
    if (_decoded) return _bytes;
    _decoded = true;
    final i = image.indexOf(';base64,');
    if (image.startsWith('data:image') && i > 0 && !image.startsWith('data:image/svg')) {
      try {
        _bytes = base64Decode(image.substring(i + 8));
      } catch (_) {}
    }
    return _bytes;
  }

  bool get isNetworkImage => image.startsWith('http');
}
