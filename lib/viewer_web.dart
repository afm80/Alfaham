import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'models.dart';
import 'ui.dart';

/// نسخة الويب: تعرض كود اللوحة داخل iframe على نفس نطاق الموقع،
/// فتعمل اللوحة وتتصل بقاعدة بياناتها كما كانت تعمل سابقاً.
class ViewerScreen extends StatefulWidget {
  final CardItem card;
  const ViewerScreen({super.key, required this.card});

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  int _gen = 0;
  bool _full = false;
  String? _blobUrl;
  final List<String> _errs = [];
  JSFunction? _listener;

  // سكربت يُحقن داخل الكرت (سطر واحد حتى لا تتغير أرقام الأسطر) ويرسل الأخطاء للتطبيق.
  static const _hook = r'''<script>(function(){function s(m,l,c){try{parent.postMessage({__afm:1,msg:m,line:l||0,col:c||0},'*')}catch(_){}}addEventListener('error',function(e){var t=e.target;if(t&&t!==window&&t.tagName){var u=String(t.currentSrc||t.src||t.href||'');if(u.indexOf('data:')===0)u='data:...';s('[تعذر تحميل '+String(t.tagName).toLowerCase()+'] '+u.slice(0,200));return}s(String(e.message||(e.error&&e.error.message)||'خطأ غير معروف'),e.lineno,e.colno)},true);addEventListener('unhandledrejection',function(e){var r=e.reason;s('Promise: '+String(r&&r.message?r.message:r))});var ce=console.error;console.error=function(){try{s('console.error: '+Array.prototype.slice.call(arguments).map(String).join(' ').slice(0,300))}catch(_){}ce.apply(console,arguments)}})();</script>''';

  /// يحقن السكربت بعد <head> (أو <html> أو <!doctype>) كي لا يتغير وضع العرض (quirks mode).
  String _withHook(String code) {
    for (final re in [
      RegExp(r'<head(\s[^>]*)?>', caseSensitive: false),
      RegExp(r'<html(\s[^>]*)?>', caseSensitive: false),
      RegExp(r'<!doctype[^>]*>', caseSensitive: false),
    ]) {
      final m = re.firstMatch(code);
      if (m != null) return code.substring(0, m.end) + _hook + code.substring(m.end);
    }
    return _hook + code;
  }

  @override
  void initState() {
    super.initState();
    _listener = ((web.MessageEvent e) => _onMessage(e.data)).toJS;
    web.window.addEventListener('message', _listener!);
  }

  void _onMessage(JSAny? raw) {
    final d = raw.dartify();
    if (d is! Map || d['__afm'] != 1) return;
    final msg = d['msg'].toString();
    final line = (d['line'] is num) ? (d['line'] as num).toInt() : 0;
    final col = (d['col'] is num) ? (d['col'] as num).toInt() : 0;
    final lines = widget.card.code.split('\n');
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

  void _revoke() {
    final u = _blobUrl;
    if (u != null) {
      try {
        web.URL.revokeObjectURL(u);
      } catch (_) {}
      _blobUrl = null;
    }
  }

  @override
  void dispose() {
    if (_listener != null) web.window.removeEventListener('message', _listener!);
    _revoke();
    super.dispose();
  }

  void _init(Object el) {
    final f = el as web.HTMLIFrameElement;
    // نستخدم Blob URL بدل srcdoc: في srcdoc أي رابط نسبي أو href="#" يُحل على عنوان
    // تطبيق Flutter نفسه، وبسبب rewrite (** -> /index.html) يُحمَّل التطبيق داخل iframe
    // ثم داخل نفسه بلا نهاية فتتجمد الشاشة. الـ Blob له رابط خاص به ونفس الأصل (Origin).
    _revoke();
    final blob = web.Blob(
      [_withHook(widget.card.code).toJS].toJS as JSArray<JSAny>,
      web.BlobPropertyBag(type: 'text/html;charset=utf-8'),
    );
    _blobUrl = web.URL.createObjectURL(blob);
    f.src = _blobUrl!;
    f.allow = 'clipboard-write; fullscreen; camera; microphone';
    f.style.border = 'none';
    f.style.width = '100%';
    f.style.height = '100%';
    f.style.background = '#ffffff';
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

  @override
  Widget build(BuildContext context) {
    return GradientBg(
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
                  IconButton(
                    tooltip: 'تحديث',
                    onPressed: () => setState(() {
                      _errs.clear();
                      _gen++;
                    }),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                  IconButton(tooltip: 'ملء الشاشة', onPressed: () => setState(() => _full = true), icon: const Icon(Icons.fullscreen_rounded)),
                ],
              ),
        body: Stack(
          children: [
            HtmlElementView.fromTagName(key: ValueKey(_gen), tagName: 'iframe', onElementCreated: _init),
            if (_full)
              Positioned(
                top: 8,
                left: 8,
                child: Material(
                  color: const Color(0x99000000),
                  shape: const CircleBorder(),
                  child: IconButton(onPressed: () => setState(() => _full = false), icon: const Icon(Icons.fullscreen_exit_rounded, color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
