import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'api.dart';
import 'models.dart';
import 'ui.dart';
import 'viewer_screen.dart';

/// إضافة كرت جديد أو تعديل كرت موجود (نفس حقول لوحة الويب + التصنيف والتثبيت).
class EditScreen extends StatefulWidget {
  final CardItem? card;
  final List<String> categories;
  const EditScreen({super.key, this.card, this.categories = const []});

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  late final TextEditingController _title;
  late final TextEditingController _cat;
  late final TextEditingController _code;
  late bool _pinned;
  late CardItem _img;
  String? _newImage;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.card;
    _title = TextEditingController(text: c?.title ?? '');
    _cat = TextEditingController(text: c?.category ?? '');
    _code = TextEditingController(text: c?.code ?? '');
    _pinned = c?.pinned ?? false;
    _img = CardItem(id: '', title: c?.title ?? '', code: '', image: c?.image ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _cat.dispose();
    _code.dispose();
    super.dispose();
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _pickImage() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 600, maxHeight: 600, imageQuality: 85);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    final mime = x.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
    final data = 'data:$mime;base64,${base64Encode(bytes)}';
    if (!mounted) return;
    setState(() {
      _newImage = data;
      _img = CardItem(id: '', title: _title.text, code: '', image: data);
    });
  }

  Future<void> _paste() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final t = d?.text;
    if (t == null || t.isEmpty) {
      _toast('الحافظة فارغة');
      return;
    }
    setState(() => _code.text = t);
  }

  void _preview() {
    final code = _code.text.trim();
    if (code.isEmpty) {
      _toast('اكتب كود HTML أولاً');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ViewerScreen(
          card: CardItem(id: widget.card?.id ?? 'preview', title: _title.text.isEmpty ? 'معاينة' : _title.text, code: code),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final code = _code.text.trim();
    if (title.isEmpty || code.isEmpty) {
      _toast('يرجى كتابة العنوان وكود HTML على الأقل!');
      return;
    }
    setState(() => _saving = true);
    final data = <String, dynamic>{
      'title': title,
      'code': code,
      'category': _cat.text.trim(),
      'pinned': _pinned,
    };
    try {
      if (widget.card == null) {
        data['image'] = _newImage ?? '';
        data['timestamp'] = DateTime.now().millisecondsSinceEpoch;
        await Api.i.addCard(data);
      } else {
        if (_newImage != null) data['image'] = _newImage;
        await Api.i.updateCard(widget.card!.id, data);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _toast(e.message);
      }
    }
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      );

  @override
  Widget build(BuildContext context) {
    final editing = widget.card != null;
    return GradientBg(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(editing ? 'تعديل الكرت' : 'كرت جديد')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            if (widget.card?.repaired == true)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0x26FBBF24),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x80FBBF24)),
                ),
                child: const Text(
                  'تم إصلاح خطأ ترميز في كود هذا الكرت تلقائياً (رموز HTML مفكوكة داخل دالة esc). '
                  'اضغط «حفظ التعديلات» لتثبيت الإصلاح في قاعدة البيانات.',
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
              ),
            _label('اسم الكرت / القسم'),
            TextField(controller: _title, decoration: const InputDecoration(hintText: 'مثال: متجر الإلكترونيات')),
            _label('صورة القسم'),
            Row(
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(color: const Color(0x33000000), borderRadius: BorderRadius.circular(16), border: Border.all(color: C.border)),
                  clipBehavior: Clip.antiAlias,
                  padding: const EdgeInsets.all(6),
                  child: CardImage(_img),
                ),
                const SizedBox(width: 14),
                OutlinedButton.icon(onPressed: _pickImage, icon: const Icon(Icons.image_outlined), label: const Text('اختيار صورة')),
              ],
            ),
            _label('التصنيف (اختياري)'),
            TextField(controller: _cat, decoration: const InputDecoration(hintText: 'مثال: متاجر')),
            if (widget.categories.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final c in widget.categories) ActionChip(label: Text(c), onPressed: () => setState(() => _cat.text = c)),
                ],
              ),
            ],
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _pinned,
              onChanged: (v) => setState(() => _pinned = v),
              title: const Text('تثبيت في أعلى القائمة'),
              activeColor: C.accent,
            ),
            Row(
              children: [
                const Text('كود لوحة التحكم (HTML)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const Spacer(),
                TextButton.icon(onPressed: _paste, icon: const Icon(Icons.content_paste_rounded, size: 18), label: const Text('لصق')),
              ],
            ),
            TextField(
              controller: _code,
              minLines: 10,
              maxLines: 16,
              keyboardType: TextInputType.multiline,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.left,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
              decoration: const InputDecoration(hintText: 'أدخل كود HTML و CSS و JavaScript هنا...'),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                OutlinedButton.icon(onPressed: _preview, icon: const Icon(Icons.play_arrow_rounded), label: const Text('معاينة')),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: C.onAccent))
                        : Text(editing ? 'حفظ التعديلات' : 'حفظ وإضافة الكرت'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
