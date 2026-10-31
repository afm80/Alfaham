import 'package:flutter/material.dart';

import 'api.dart';
import 'edit_screen.dart';
import 'login_screen.dart';
import 'models.dart';
import 'reorder_screen.dart';
import 'ui.dart';
import 'viewer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<CardItem> _all = [];
  String _cat = 'الكل';
  String _q = '';
  bool _loading = true;
  String? _err;
  bool _moving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _init() async {
    final cached = await Api.i.readCache();
    if (mounted && cached != null) {
      setState(() {
        _all = cached;
        _loading = false;
      });
    }
    await _refresh();
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _refresh({bool quiet = true}) async {
    try {
      final l = await Api.i.fetchCards();
      if (!mounted) return;
      setState(() {
        _all = l;
        _loading = false;
        _err = null;
      });
    } on AuthExpired {
      _goLogin();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (_all.isEmpty) {
        setState(() => _err = e.message);
      } else if (!quiet) {
        _toast('${e.message} — يعرض آخر نسخة محفوظة');
      }
    }
  }

  void _goLogin() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  Future<void> _logout() async {
    if (!await confirmDialog(context, 'تسجيل الخروج', 'هل تريد تسجيل الخروج؟', ok: 'خروج')) return;
    await Api.i.signOut();
    _goLogin();
  }

  void _open(CardItem c) => Navigator.push(context, MaterialPageRoute(builder: (_) => ViewerScreen(card: c)));

  Future<void> _edit(CardItem? c) async {
    final cats = {for (final x in _all) if (x.category.isNotEmpty) x.category}.toList();
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditScreen(card: c, categories: cats)),
    );
    if (ok == true) _refresh(quiet: false);
  }

  Future<void> _reorder() async {
    if (_all.length < 2) {
      _toast('يلزم كرتان على الأقل للترتيب');
      return;
    }
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ReorderScreen(cards: List.of(_all))),
    );
    if (ok == true) {
      await _refresh(quiet: false);
      if (mounted) _toast('تم حفظ الترتيب');
    }
  }

  /// نقل الكرت خطوة واحدة (dir = -1 للتقديم، +1 للتأخير) ضمن القائمة المعروضة، ثم حفظ الترتيب.
  Future<void> _move(CardItem c, int dir, List<CardItem> visible) async {
    if (_moving) return;
    final i = visible.indexWhere((x) => x.id == c.id);
    final j = i + dir;
    if (i < 0 || j < 0 || j >= visible.length) return;
    final n = visible[j];
    if (n.pinned != c.pinned) {
      _toast('الكروت المثبّتة ⭐ تبقى دائماً في الأعلى');
      return;
    }
    final a = _all.indexWhere((x) => x.id == c.id);
    final b = _all.indexWhere((x) => x.id == n.id);
    if (a < 0 || b < 0) return;
    final backup = List<CardItem>.of(_all);
    setState(() {
      _moving = true;
      final t = _all[a];
      _all[a] = _all[b];
      _all[b] = t;
    });
    try {
      await Api.i.saveOrder([for (final x in _all) x.id]);
      await _refresh();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _all = backup);
        _toast(e.message);
      }
    } finally {
      if (mounted) setState(() => _moving = false);
    }
  }

  Future<void> _togglePin(CardItem c) async {
    try {
      await Api.i.updateCard(c.id, {'pinned': !c.pinned});
      await _refresh(quiet: false);
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    }
  }

  Future<void> _delete(CardItem c) async {
    if (!await confirmDialog(context, 'حذف الكرت', 'هل أنت متأكد من حذف "${c.title}"؟', ok: 'حذف')) return;
    try {
      await Api.i.deleteCard(c.id);
      await _refresh(quiet: false);
      if (mounted) _toast('تم حذف الكرت');
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    }
  }

  void _sheet(CardItem c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: C.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('تعديل'),
              onTap: () {
                Navigator.pop(ctx);
                _edit(c);
              },
            ),
            ListTile(
              leading: Icon(c.pinned ? Icons.star_border_rounded : Icons.star_rounded),
              title: Text(c.pinned ? 'إلغاء التثبيت' : 'تثبيت في الأعلى'),
              onTap: () {
                Navigator.pop(ctx);
                _togglePin(c);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: C.danger),
              title: const Text('حذف', style: TextStyle(color: C.danger)),
              onTap: () {
                Navigator.pop(ctx);
                _delete(c);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _message(String text, {bool retry = false}) => SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(text, textAlign: TextAlign.center, style: const TextStyle(color: C.muted)),
                if (retry) ...[
                  const SizedBox(height: 14),
                  OutlinedButton(onPressed: () => _refresh(quiet: false), child: const Text('إعادة المحاولة')),
                ],
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cats = ['الكل', ...{for (final c in _all) if (c.category.isNotEmpty) c.category}];
    if (!cats.contains(_cat)) _cat = 'الكل';
    final q = _q.toLowerCase();
    final list = _all.where((c) => (_cat == 'الكل' || c.category == _cat) && c.title.toLowerCase().contains(q)).toList();

    return GradientBg(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(null),
          icon: const Icon(Icons.add),
          label: const Text('كرت جديد', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        body: SafeArea(
          child: RefreshIndicator(
            color: C.accent,
            backgroundColor: C.surface,
            onRefresh: () => _refresh(quiet: false),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                    child: Row(
                      children: [
                        Image.asset('assets/icon/mark.png', height: 36),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Alfaham Admin', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                              Text('${_all.length} لوحة تحكم', style: const TextStyle(color: C.muted, fontSize: 12)),
                            ],
                          ),
                        ),
                        IconButton(tooltip: 'ترتيب الكروت', onPressed: _reorder, icon: const Icon(Icons.swap_vert_rounded)),
                        IconButton(tooltip: 'تحديث', onPressed: () => _refresh(quiet: false), icon: const Icon(Icons.refresh_rounded)),
                        IconButton(tooltip: 'خروج', onPressed: _logout, icon: const Icon(Icons.logout_rounded)),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: TextField(
                      onChanged: (v) => setState(() => _q = v.trim()),
                      decoration: const InputDecoration(hintText: 'ابحث في الأقسام...', prefixIcon: Icon(Icons.search_rounded)),
                    ),
                  ),
                ),
                if (cats.length > 1)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 46,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: cats.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final sel = cats[i] == _cat;
                          return ChoiceChip(
                            label: Text(cats[i]),
                            selected: sel,
                            showCheckmark: false,
                            selectedColor: C.accent,
                            backgroundColor: Colors.transparent,
                            side: const BorderSide(color: C.border),
                            labelStyle: TextStyle(color: sel ? C.onAccent : C.muted, fontWeight: sel ? FontWeight.w700 : FontWeight.w500),
                            onSelected: (_) => setState(() => _cat = cats[i]),
                          );
                        },
                      ),
                    ),
                  ),
                if (_loading)
                  const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator(color: C.accent)))
                else if (_err != null && list.isEmpty)
                  _message('تعذّر تحميل البيانات\n$_err', retry: true)
                else if (list.isEmpty)
                  _message(_all.isEmpty ? 'لا توجد أقسام مضافة بعد.\nاضغط "كرت جديد" لإضافة أول لوحة تحكم.' : 'لا توجد نتائج.')
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 190,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.64,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _Tile(
                          card: list[i],
                          onTap: () => _open(list[i]),
                          onLong: () => _sheet(list[i]),
                          onEdit: () => _edit(list[i]),
                          onDelete: () => _delete(list[i]),
                          onPrev: i > 0 && !_moving ? () => _move(list[i], -1, list) : null,
                          onNext: i < list.length - 1 && !_moving ? () => _move(list[i], 1, list) : null,
                        ),
                        childCount: list.length,
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

class _Tile extends StatelessWidget {
  final CardItem card;
  final VoidCallback onTap;
  final VoidCallback onLong;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  const _Tile({
    required this.card,
    required this.onTap,
    required this.onLong,
    required this.onEdit,
    required this.onDelete,
    this.onPrev,
    this.onNext,
  });

  /// زر سهم (الاتجاه ثابت LTR حتى لا ينعكس السهم في الواجهة العربية).
  Widget _arrow(IconData icon, String tip, VoidCallback? f) => Expanded(
        child: Tooltip(
          message: tip,
          child: Material(
            color: Color(f == null ? 0x08FFFFFF : 0x1AFFFFFF),
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: f,
              child: SizedBox(
                height: 30,
                child: Center(
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Icon(icon, size: 20, color: f == null ? const Color(0x449DB3BD) : C.accent),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _action(IconData icon, String label, Color color, VoidCallback f) => Expanded(
        child: Tooltip(
          message: label,
          child: Material(
            color: color.withOpacity(0.18),
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: f,
              child: Container(
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withOpacity(0.55)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 4),
                    Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(20);
    return Container(
      decoration: BoxDecoration(
        borderRadius: r,
        gradient: const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [C.surface2, C.surface]),
        border: Border.all(color: C.border),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: r,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLong,
          onSecondaryTap: onLong, // زر الماوس الأيمن في الويب
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Container(width: double.infinity, color: const Color(0x33000000), child: CardImage(card)),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                    child: Text(card.title, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
                    child: Row(
                      children: [
                        _action(Icons.edit_rounded, 'تعديل', const Color(0xFF34D399), onEdit),
                        const SizedBox(width: 8),
                        _action(Icons.delete_rounded, 'حذف', const Color(0xFFFB7185), onDelete),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: Row(
                      children: [
                        // في الواجهة العربية بداية القائمة على اليمين: السهم → يقدّم الكرت، والسهم ← يؤخّره
                        _arrow(Icons.arrow_forward_rounded, 'تقديم الكرت', onPrev),
                        const SizedBox(width: 8),
                        _arrow(Icons.arrow_back_rounded, 'تأخير الكرت', onNext),
                      ],
                    ),
                  ),
                ],
              ),
              if (card.pinned) const Positioned(top: 8, right: 8, child: Icon(Icons.star_rounded, color: C.star, size: 20)),
            ],
          ),
        ),
      ),
    );
  }
}
