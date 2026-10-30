import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'models.dart';
import 'ui.dart';

/// نسخة الويب: تعرض كود اللوحة داخل iframe (srcdoc) على نفس نطاق الموقع،
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

  void _init(Object el) {
    final f = el as web.HTMLIFrameElement;
    f.srcdoc = widget.card.code;
    f.allow = 'clipboard-write; fullscreen; camera; microphone';
    f.style.border = 'none';
    f.style.width = '100%';
    f.style.height = '100%';
    f.style.background = '#ffffff';
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
                  IconButton(tooltip: 'تحديث', onPressed: () => setState(() => _gen++), icon: const Icon(Icons.refresh_rounded)),
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
