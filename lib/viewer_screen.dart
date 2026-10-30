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
  double _progress = 0;
  bool _full = false;
  final List<String> _errs = [];

  Uri get _base => Uri.parse('${AppConfig.webOrigin}/run/${Uri.encodeComponent(widget.card.id)}.html');

  Future<void> _load() async {
    setState(() => _errs.clear());
    await _c?.loadData(data: widget.card.code, baseUrl: WebUri.uri(_base), mimeType: 'text/html', encoding: 'utf-8');
  }

  void _toggleFull() {
    setState(() => _full = !_full);
    SystemChrome.setEnabledSystemUIMode(_full ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
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
                    data: widget.card.code,
                    baseUrl: WebUri.uri(_base),
                    mimeType: 'text/html',
                    encoding: 'utf-8',
                  ),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    domStorageEnabled: true,
                    databaseEnabled: true,
                    useShouldOverrideUrlLoading: true,
                    mediaPlaybackRequiresUserGesture: false,
                    allowsInlineMediaPlayback: true,
                    javaScriptCanOpenWindowsAutomatically: true,
                    thirdPartyCookiesEnabled: true,
                    mixedContentMode: MixedContentMode.MIXED_CONTENT_COMPATIBILITY_MODE,
                  ),
                  onWebViewCreated: (c) => _c = c,
                  onProgressChanged: (_, p) => setState(() => _progress = p / 100),
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
