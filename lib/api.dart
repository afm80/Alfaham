import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'models.dart';

class ApiException implements Exception {
  final String message;
  final bool network;
  ApiException(this.message, {this.network = false});
  @override
  String toString() => message;
}

/// تنتهي الجلسة ويجب تسجيل الدخول من جديد.
class AuthExpired extends ApiException {
  AuthExpired() : super('انتهت الجلسة، سجّل الدخول من جديد');
}

/// يتعامل مع Firebase Auth و Realtime Database عبر REST
/// (لا يحتاج google-services.json ولا أي إعداد أصلي).
class Api {
  Api._();
  static final Api i = Api._();

  String? _idToken;
  String? _refreshToken;
  DateTime _exp = DateTime(2000);
  String email = '';

  bool get signedIn => _refreshToken != null;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _refreshToken = p.getString('rt');
    email = p.getString('email') ?? '';
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    if (_refreshToken == null) {
      await p.remove('rt');
    } else {
      await p.setString('rt', _refreshToken!);
    }
    await p.setString('email', email);
  }

  void _apply(dynamic id, dynamic refresh, dynamic expiresIn) {
    _idToken = id?.toString();
    _refreshToken = refresh?.toString();
    final s = int.tryParse(expiresIn?.toString() ?? '') ?? 3600;
    _exp = DateTime.now().add(Duration(seconds: s));
  }

  // ───────── HTTP ─────────
  Future<dynamic> _send(Future<http.Response> Function() f) async {
    http.Response r;
    try {
      r = await f().timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw ApiException('انتهت مهلة الاتصال', network: true);
    } catch (_) {
      throw ApiException('تحقق من الاتصال بالإنترنت', network: true);
    }
    dynamic body;
    try {
      body = r.body.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {}
    if (r.statusCode >= 400) throw ApiException(_err(body, r.statusCode));
    return body;
  }

  String _err(dynamic b, int code) {
    var m = '';
    if (b is Map) {
      final e = b['error'];
      if (e is Map) {
        m = (e['message'] ?? '').toString();
      } else if (e != null) {
        m = e.toString();
      }
    }
    if (m.contains('INVALID_LOGIN_CREDENTIALS') || m.contains('INVALID_PASSWORD') || m.contains('EMAIL_NOT_FOUND')) {
      return 'البريد أو كلمة المرور غير صحيحة';
    }
    if (m.contains('INVALID_EMAIL')) return 'صيغة البريد غير صحيحة';
    if (m.contains('TOO_MANY_ATTEMPTS')) return 'محاولات كثيرة، انتظر قليلاً';
    if (m.contains('USER_DISABLED')) return 'تم تعطيل هذا الحساب';
    if (code == 401 || code == 403 || m.contains('Permission denied')) return 'لا تملك صلاحية الوصول';
    return 'خطأ: ${m.isEmpty ? code : m}';
  }

  // ───────── Auth ─────────
  Future<void> signIn(String mail, String pass) async {
    final r = await _send(() => http.post(
          Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${AppConfig.apiKey}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': mail, 'password': pass, 'returnSecureToken': true}),
        ));
    _apply(r['idToken'], r['refreshToken'], r['expiresIn']);
    email = (r['email'] ?? mail).toString();
    await _save();
  }

  Future<void> signOut() async {
    _idToken = null;
    _refreshToken = null;
    await _save();
    try {
      final f = await _cacheFile();
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  Future<String> _token() async {
    if (_idToken != null && DateTime.now().isBefore(_exp.subtract(const Duration(minutes: 2)))) {
      return _idToken!;
    }
    final rt = _refreshToken;
    if (rt == null) throw AuthExpired();
    try {
      final r = await _send(() => http.post(
            Uri.parse('https://securetoken.googleapis.com/v1/token?key=${AppConfig.apiKey}'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {'grant_type': 'refresh_token', 'refresh_token': rt},
          ));
      _apply(r['id_token'], r['refresh_token'], r['expires_in']);
      await _save();
      return _idToken!;
    } on ApiException catch (e) {
      if (e.network) rethrow;
      await signOut();
      throw AuthExpired();
    }
  }

  // ───────── Database ─────────
  Uri _u(String path, String token) =>
      Uri.parse('${AppConfig.dbUrl}/$path.json').replace(queryParameters: {'auth': token});

  Future<List<CardItem>> fetchCards() async {
    final t = await _token();
    final b = await _send(() => http.get(_u('cards', t)));
    _writeCache(b);
    return _parse(b);
  }

  List<CardItem> _parse(dynamic b) {
    final list = <CardItem>[];
    if (b is Map) {
      b.forEach((k, v) {
        if (v is Map) list.add(CardItem.fromMap(k.toString(), v));
      });
    }
    list.sort((a, b) {
      final p = (b.pinned ? 1 : 0) - (a.pinned ? 1 : 0);
      if (p != 0) return p;
      final ao = a.order, bo = b.order;
      if (ao == null && bo == null) return b.timestamp.compareTo(a.timestamp);
      if (ao == null) return -1; // الكروت الجديدة (بلا ترتيب) تظهر أولاً
      if (bo == null) return 1;
      return ao != bo ? ao.compareTo(bo) : b.timestamp.compareTo(a.timestamp);
    });
    return list;
  }

  Future<void> addCard(Map<String, dynamic> data) async {
    final t = await _token();
    await _send(() => http.post(_u('cards', t), body: jsonEncode(data)));
  }

  Future<void> updateCard(String id, Map<String, dynamic> data) async {
    final t = await _token();
    await _send(() => http.patch(_u('cards/$id', t), body: jsonEncode(data)));
  }

  /// يحفظ الترتيب اليدوي: يكتب الحقل order لكل كرت بطلب واحد (تحديث متعدد المسارات).
  Future<void> saveOrder(List<String> ids) async {
    final t = await _token();
    final body = {for (var i = 0; i < ids.length; i++) '${ids[i]}/order': i};
    await _send(() => http.patch(_u('cards', t), body: jsonEncode(body)));
  }

  Future<void> deleteCard(String id) async {
    final t = await _token();
    await _send(() => http.delete(_u('cards/$id', t)));
  }

  // ───────── Cache (عرض فوري + وضع بدون إنترنت) ─────────
  Future<File> _cacheFile() async {
    final d = await getApplicationDocumentsDirectory();
    return File('${d.path}/cards_cache.json');
  }

  Future<void> _writeCache(dynamic b) async {
    try {
      await (await _cacheFile()).writeAsString(jsonEncode(b));
    } catch (_) {}
  }

  Future<List<CardItem>?> readCache() async {
    try {
      final f = await _cacheFile();
      if (!await f.exists()) return null;
      return _parse(jsonDecode(await f.readAsString()));
    } catch (_) {
      return null;
    }
  }
}
