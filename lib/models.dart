import 'dart:convert';
import 'dart:typed_data';

/// بعض الكروت المخزّنة في القاعدة تعرّضت لفكّ ترميز HTML (&amp; &lt; &gt; &quot; &#39;)
/// فأصبح جدول التهريب في دالة esc() هكذا:  {'&':'&','<':'<','>':'>','"':'"',"'":'''}
/// والقيمة ''' خطأ نحوي (SyntaxError) يوقف كل سكربت الكرت فلا يجلب بيانات القاعدة.
/// هذه الدالة تعيد الجدول لصورته الصحيحة، وتعمل فقط عند اكتشاف هذا العطب بالتحديد.
class CodeFix {
  static final _apos = RegExp("(\"'\"\\s*:\\s*)'''");
  static final _amp = RegExp(r"('&'\s*:\s*)'&'");
  static final _lt = RegExp(r"('<'\s*:\s*)'<'");
  static final _gt = RegExp(r"('>'\s*:\s*)'>'");
  static final _quot = RegExp("('\"'\\s*:\\s*)'\"'");

  /// شعار بديل (data URI) يُحمَّل عند بدء التطبيق من assets/icon/mark.png.
  static String? logoUri;

  // الكروت القديمة تشير إلى ./assets/site-logo.png وهو ملف كان على الموقع السابق ولم يعد موجوداً،
  // فنستبدله وقت العرض فقط (لا نعدّل ما في القاعدة) بشعار التطبيق.
  static final _logo = RegExp(r'(?<![\w./-])(?:\.{0,2}/)*assets/site-logo\.png');

  /// يُستعمل عند العرض فقط (WebView / iframe).
  static String forView(String code) {
    final u = logoUri;
    if (u == null || !code.contains('site-logo.png')) return code;
    return code.replaceAll(_logo, u);
  }

  static bool isBroken(String code) => _apos.hasMatch(code);

  static String repair(String code) {
    if (!isBroken(code)) return code;
    return code
        .replaceAllMapped(_amp, (m) => "${m[1]}'&amp;'")
        .replaceAllMapped(_lt, (m) => "${m[1]}'&lt;'")
        .replaceAllMapped(_gt, (m) => "${m[1]}'&gt;'")
        .replaceAllMapped(_quot, (m) => "${m[1]}'&quot;'")
        .replaceAllMapped(_apos, (m) => "${m[1]}'&#39;'");
  }
}

class CardItem {
  final String id;
  final String title;
  final String code;
  final String image;
  final String category;
  final bool pinned;
  final int timestamp;

  /// true إذا أُصلح كود الكرت تلقائياً عند التحميل (انظر CodeFix).
  final bool repaired;

  /// ترتيب الكرت اليدوي (null = لم يُرتَّب بعد، فيظهر في الأعلى حسب الأحدث).
  final int? order;

  CardItem({
    required this.id,
    required this.title,
    required this.code,
    this.image = '',
    this.category = '',
    this.pinned = false,
    this.timestamp = 0,
    this.repaired = false,
    this.order,
  });

  factory CardItem.fromMap(String id, Map m) {
    final raw = (m['code'] ?? '').toString();
    final fixed = CodeFix.repair(raw);
    return CardItem(
      id: id,
      title: (m['title'] ?? '').toString(),
      code: fixed,
      image: (m['image'] ?? '').toString(),
      category: (m['category'] ?? '').toString(),
      pinned: m['pinned'] == true,
      timestamp: m['timestamp'] is num ? (m['timestamp'] as num).toInt() : 0,
      repaired: fixed != raw,
      order: m['order'] is num ? (m['order'] as num).toInt() : null,
    );
  }

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
