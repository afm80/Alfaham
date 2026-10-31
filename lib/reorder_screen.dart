import 'package:flutter/material.dart';

import 'api.dart';
import 'models.dart';
import 'ui.dart';

/// ترتيب الكروت بالسحب والإفلات (يعمل في الأندرويد والويب).
/// الترتيب يُحفظ في حقل order لكل كرت. الكروت المثبّتة تبقى في الأعلى.
class ReorderScreen extends StatefulWidget {
  final List<CardItem> cards;
  const ReorderScreen({super.key, required this.cards});

  @override
  State<ReorderScreen> createState() => _ReorderScreenState();
}

class _ReorderScreenState extends State<ReorderScreen> {
  late List<CardItem> _list = List.of(widget.cards);
  bool _saving = false;
  bool _changed = false;

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await Api.i.saveOrder([for (final c in _list) c.id]);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _toast(e.message);
      }
    }
  }

  void _moveBy(int i, int d) {
    final j = i + d;
    if (j < 0 || j >= _list.length) return;
    setState(() {
      final t = _list[i];
      _list[i] = _list[j];
      _list[j] = t;
      _changed = true;
    });
  }

  Future<bool> _confirmExit() async {
    if (!_changed || _saving) return true;
    return confirmDialog(context, 'تجاهل التغييرات', 'لم تحفظ الترتيب الجديد، هل تريد الخروج؟', ok: 'خروج');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_changed || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmExit() && mounted) Navigator.pop(context);
      },
      child: GradientBg(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('ترتيب الكروت'),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: TextButton.icon(
                  onPressed: (_saving || !_changed) ? null : _save,
                  icon: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: C.accent))
                      : const Icon(Icons.check_rounded),
                  label: const Text('حفظ', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: const [
                    Icon(Icons.drag_indicator_rounded, size: 18, color: C.muted),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'استخدم الأسهم ↑ ↓ أو اسحب المقبض لتغيير مكان الكرت ثم اضغط «حفظ». الكروت المثبّتة ⭐ تبقى دائماً في الأعلى.',
                        style: TextStyle(color: C.muted, fontSize: 12.5, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  buildDefaultDragHandles: false,
                  itemCount: _list.length,
                  onReorder: (from, to) {
                    setState(() {
                      if (to > from) to -= 1;
                      final it = _list.removeAt(from);
                      _list.insert(to, it);
                      _changed = true;
                    });
                  },
                  itemBuilder: (_, i) {
                    final c = _list[i];
                    return Container(
                      key: ValueKey(c.id),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: C.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: C.border),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsetsDirectional.fromSTEB(12, 6, 4, 6),
                        leading: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(color: const Color(0x33000000), borderRadius: BorderRadius.circular(12)),
                          clipBehavior: Clip.antiAlias,
                          padding: const EdgeInsets.all(4),
                          child: CardImage(c),
                        ),
                        title: Row(
                          children: [
                            Expanded(child: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
                            if (c.pinned) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.star_rounded, color: C.star, size: 18)),
                          ],
                        ),
                        subtitle: c.category.isEmpty ? null : Text(c.category, style: const TextStyle(color: C.muted, fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'للأعلى',
                              visualDensity: VisualDensity.compact,
                              onPressed: i > 0 ? () => _moveBy(i, -1) : null,
                              icon: const Icon(Icons.arrow_upward_rounded),
                              color: C.accent,
                            ),
                            IconButton(
                              tooltip: 'للأسفل',
                              visualDensity: VisualDensity.compact,
                              onPressed: i < _list.length - 1 ? () => _moveBy(i, 1) : null,
                              icon: const Icon(Icons.arrow_downward_rounded),
                              color: C.accent,
                            ),
                            ReorderableDragStartListener(
                              index: i,
                              child: const Padding(
                                padding: EdgeInsets.all(8),
                                child: Icon(Icons.drag_handle_rounded, color: C.muted),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
