import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config.dart';
import 'models.dart';
import 'ui.dart';

/// يفتح لوحة التحكم المخزّنة (HTML) داخل WebView.
/// كل لوحة تهيّئ Firebase الخاص بها وتقرأ بيانات مشروعها هي، تماماً كما في نسخة الويب،
/// لأن الصفحة تُحمَّل بنفس الأصل (Origin) الذي كانت تعمل عليه.
class ViewerScreen extends StatefulWidget {
  final CardItem card;
  const ViewerScreen({super.key, required this.card});

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  InAppWebViewController? _c;
  late final String _code = CodeFix.forView(widget.card.code);
  double _progress = 0;
  bool _full = false;
  final List<String> _errs = [];
  final List<String> _reqs = []; // آخر الطلبات (لتشخيص الصفحات العالقة)
  Timer? _watch;

  static const _hook = r'''
window.addEventListener('error', function(e){
  try{
    var t = e.target;
    if (t && t !== window && t.tagName) {
      // خطأ تحميل مورد (صورة/سكربت/ستايل) وليس خطأ جافاسكربت
      if (t.tagName === 'IMG' && !t.__afmRetry && /^https?:/.test(t.src || '')) {
        // بعض المواقع (مثل top4top) تمنع الصور عند وجود Referer غريب؛ نعيد المحاولة مرة واحدة بدونه
        t.__afmRetry = 1;
        try { t.referrerPolicy = 'no-referrer'; var s0 = t.src; t.removeAttribute('src'); t.src = s0; } catch(_){}
        return;
      }
      var u = String(t.currentSrc || t.src || t.href || '');
      if (u.indexOf('data:') === 0) u = 'data:...';
      window.flutter_inappwebview.callHandler('pageError', '[تعذر تحميل ' + String(t.tagName).toLowerCase() + '] ' + u.slice(0, 200), 0, 0, '');
      return;
    }
    var m = e.message || (e.error && e.error.message) || 'خطأ غير معروف';
    window.flutter_inappwebview.callHandler('pageError', String(m), e.lineno||0, e.colno||0, String(e.filename||''));
  }catch(_){}
}, true);
window.addEventListener('unhandledrejection', function(e){
  try{ var r=e.reason; window.flutter_inappwebview.callHandler('pageError', 'Promise: '+String(r&&r.message?r.message:r), 0, 0, ''); }catch(_){}
});
''';

  /// يعرض موضع الخطأ داخل كود الكرت (السطر والعمود والحرف المشبوه).
  void _onPageError(List a) {
    if (a.length < 3) return;
    final msg = a[0].toString();
    final line = int.tryParse(a[1].toString()) ?? 0;
    final col = int.tryParse(a[2].toString()) ?? 0;
    final lines = _code.split('\n');
    var s = msg;
    if (line > 0 && line <= lines.length) {
      final l = lines[line - 1];
      if (l.isNotEmpty) {
        final i = (col - 1).clamp(0, l.length - 1).toInt();
        final from = (i - 40).clamp(0, l.length).toInt();
        final to = (i + 40).clamp(0, l.length).toInt();
        final hex = l.codeUnitAt(i).toRadixString(16).toUpperCase().padLeft(4, '0');
        s = '$msg\nسطر $line عمود $col | الحرف U+$hex\n…${l.substring(from, to)}…';
      } else {
        s = '$msg\nسطر $line عمود $col (سطر فارغ)';
      }
    }
    if (mounted && !_errs.contains(s)) setState(() => _errs.add(s));
  }

  Uri get _base => Uri.parse('${AppConfig.webOrigin}/run/${Uri.encodeComponent(widget.card.id)}.html');

  Future<void> _load() async {
    setState(() => _errs.clear());
    await _c?.loadData(
      data: _code,
      baseUrl: WebUri.uri(_base),
      historyUrl: WebUri.uri(_base),
      mimeType: 'text/html',
      encoding: 'utf-8',
    );
  }

  void _toggleFull() {
    setState(() => _full = !_full);
    SystemChrome.setEnabledSystemUIMode(_full ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    _watch?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _showErrors() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('أخطاء الصفحة (${_errs.length})'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(_errs.join('\n\n'), textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 12, color: Color(0xFFFCA5A5))),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
      ),
    );
  }

  Future<void> _dialog(String msg) => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          content: Text(msg),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسناً'))],
        ),
      );

  Future<bool> _ask(String msg) async {
    final r = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('موافق')),
        ],
      ),
    );
    return r == true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_c != null && await _c!.canGoBack()) {
          _c!.goBack();
        } else if (mounted) {
          Navigator.pop(context);
        }
      },
      child: GradientBg(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: _full
              ? null
              : AppBar(
                  leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                  title: Text(widget.card.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  actions: [
                    if (_errs.isNotEmpty)
                      IconButton(
                        tooltip: 'أخطاء',
                        onPressed: _showErrors,
                        icon: Badge(label: Text('${_errs.length}'), child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFFBBF24))),
                      ),
                    IconButton(tooltip: 'تحديث', onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
                    IconButton(tooltip: 'ملء الشاشة', onPressed: _toggleFull, icon: const Icon(Icons.fullscreen_rounded)),
                  ],
                ),
          body: SafeArea(
            top: false,
            child: Stack(
              children: [
                InAppWebView(
                  initialData: InAppWebViewInitialData(
                    data: _code,
                    baseUrl: WebUri.uri(_base),
                    historyUrl: WebUri.uri(_base),
                    mimeType: 'text/html',
                    encoding: 'utf-8',
                  ),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    useShouldInterceptRequest: true,
                    domStorageEnabled: true,
                    databaseEnabled: true,
                    useShouldOverrideUrlLoading: true,
                    mediaPlaybackRequiresUserGesture: false,
                    allowsInlineMediaPlayback: true,
                    javaScriptCanOpenWindowsAutomatically: true,
                    thirdPartyCookiesEnabled: true,
                    mixedContentMode: MixedContentMode.MIXED_CONTENT_COMPATIBILITY_MODE,
                  ),
                  onWebViewCreated: (c) {
                    _c = c;
                    c.addJavaScriptHandler(
                      handlerName: 'pageError',
                      callback: (a) {
                        _onPageError(a);
                        return null;
                      },
                    );
                  },
                  initialUserScripts: UnmodifiableListView<UserScript>([
                    UserScript(source: _hook, injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START),
                  ]),
                  // الصفحة تعيش على رابطها الوهمي (/run/<id>.html). السيرفر الحقيقي يرد بـ index.html
                  // لأي مسار (rewrite)، فنُرجع كود الكرت بأنفسنا عند إعادة التحميل / الرجوع / reload
                  // حتى لا تتحول الصفحة إلى شاشة بيضاء أو تُحمّل التطبيق نفسه.
                  shouldInterceptRequest: (_, req) async {
                    final u = Uri.tryParse(req.url.toString());
                    _reqs.add(req.url.toString());
                    if (_reqs.length > 8) _reqs.removeAt(0);
                    if (u != null && u.host == _base.host && u.path == _base.path) {
                      return WebResourceResponse(
                        contentType: 'text/html',
                        contentEncoding: 'utf-8',
                        data: Uint8List.fromList(utf8.encode(_code)),
                      );
                    }
                    return null;
                  },
                  onLoadStart: (_, __) {
                    _watch?.cancel();
                    _watch = Timer(const Duration(seconds: 15), () {
                      if (!mounted || _progress >= 1) return;
                      final s = 'الصفحة ما زالت تُحمَّل بعد 15 ثانية (${(_progress * 100).round()}%)\nآخر الطلبات:\n${_reqs.join('\n')}';
                      if (!_errs.contains(s)) setState(() => _errs.add(s));
                    });
                  },
                  onLoadStop: (_, __) => _watch?.cancel(),
                  onReceivedError: (_, req, err) {
                    if (req.isForMainFrame == true && mounted) {
                      final s = 'تعذر تحميل الصفحة: ${err.description}';
                      if (!_errs.contains(s)) setState(() => _errs.add(s));
                    }
                  },
                  onRenderProcessGone: (_, __) {
                    // انهيار عملية العرض (يسبب شاشة بيضاء) — نعيد التحميل تلقائياً
                    if (mounted) _load();
                  },
                  onProgressChanged: (_, p) {
                    if (mounted) setState(() => _progress = p / 100);
                  },
                  onConsoleMessage: (_, m) {
                    if (m.messageLevel == ConsoleMessageLevel.ERROR && !_errs.contains(m.message)) {
                      setState(() => _errs.add(m.message));
                    }
                  },
                  shouldOverrideUrlLoading: (_, action) async {
                    final u = action.request.url;
                    if (u == null) return NavigationActionPolicy.ALLOW;
                    const ok = ['http', 'https', 'about', 'data', 'blob', 'file', 'javascript'];
                    if (ok.contains(u.scheme)) return NavigationActionPolicy.ALLOW;
                    try {
                      await launchUrl(Uri.parse(u.toString()), mode: LaunchMode.externalApplication);
                    } catch (_) {}
                    return NavigationActionPolicy.CANCEL;
                  },
                  onPermissionRequest: (_, r) async =>
                      PermissionResponse(resources: r.resources, action: PermissionResponseAction.GRANT),
                  onJsAlert: (_, r) async {
                    await _dialog(r.message ?? '');
                    return JsAlertResponse(handledByClient: true, action: JsAlertResponseAction.CONFIRM);
                  },
                  onJsConfirm: (_, r) async {
                    final ok = await _ask(r.message ?? '');
                    return JsConfirmResponse(
                      handledByClient: true,
                      action: ok ? JsConfirmResponseAction.CONFIRM : JsConfirmResponseAction.CANCEL,
                    );
                  },
                  onJsPrompt: (_, r) async {
                    final tc = TextEditingController(text: r.defaultValue ?? '');
                    final ok = await showDialog<bool>(
                      context: context,
                      barrierDismissible: false,
                      builder: (ctx) => AlertDialog(
                        title: Text(r.message ?? ''),
                        content: TextField(controller: tc, autofocus: true),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('موافق')),
                        ],
                      ),
                    );
                    return JsPromptResponse(
                      handledByClient: true,
                      value: tc.text,
                      action: ok == true ? JsPromptResponseAction.CONFIRM : JsPromptResponseAction.CANCEL,
                    );
                  },
                ),
                if (_progress < 1)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(value: _progress, minHeight: 3, color: C.accent, backgroundColor: Colors.transparent),
                  ),
                if (_full)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: SafeArea(
                      child: Material(
                        color: const Color(0x99000000),
                        shape: const CircleBorder(),
                        child: IconButton(onPressed: _toggleFull, icon: const Icon(Icons.fullscreen_exit_rounded, color: Colors.white)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
