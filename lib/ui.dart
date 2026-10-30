import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'models.dart';

/// ألوان مستمدة من شعار Alfaham Admin (أزرق مخضر داكن + أبيض).
class C {
  static const bg = Color(0xFF0E1A21);
  static const bg2 = Color(0xFF214556);
  static const surface = Color(0xFF16272F);
  static const surface2 = Color(0xFF1F3744);
  static const border = Color(0x1FFFFFFF);
  static const accent = Color(0xFF8FD6EA);
  static const onAccent = Color(0xFF06222B);
  static const muted = Color(0xFF9DB3BD);
  static const danger = Color(0xFFEF5350);
  static const star = Color(0xFFFFC857);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: C.accent, brightness: Brightness.dark).copyWith(
    primary: C.accent,
    onPrimary: C.onAccent,
    surface: C.surface,
    error: C.danger,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: C.bg,
  );
  OutlineInputBorder ob(Color c, [double w = 0]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: w == 0 ? BorderSide.none : BorderSide(color: c, width: w),
      );
  return base.copyWith(
    textTheme: GoogleFonts.cairoTextTheme(base.textTheme).apply(bodyColor: Colors.white, displayColor: Colors.white),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0x14FFFFFF),
      hintStyle: const TextStyle(color: C.muted),
      border: ob(Colors.transparent),
      enabledBorder: ob(Colors.transparent),
      focusedBorder: ob(C.accent, 1.2),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: C.accent,
        foregroundColor: C.onAccent,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 50),
        side: const BorderSide(color: C.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.cairo(fontWeight: FontWeight.w600),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: C.accent,
      foregroundColor: C.onAccent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

class GradientBg extends StatelessWidget {
  final Widget child;
  const GradientBg({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(center: Alignment(0, -0.35), radius: 1.25, colors: [C.bg2, C.bg]),
        ),
        child: child,
      );
}

Future<bool> confirmDialog(BuildContext context, String title, String msg, {String ok = 'نعم'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(msg),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ok)),
      ],
    ),
  );
  return r == true;
}

/// صورة الكرت: base64 من القاعدة، أو رابط، أو حرف أول كبديل.
class CardImage extends StatelessWidget {
  final CardItem card;
  const CardImage(this.card, {super.key});

  Widget _ph() => Center(
        child: Text(
          card.title.isEmpty ? 'A' : card.title.characters.first.toUpperCase(),
          style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: C.accent),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final b = card.imageBytes;
    if (b != null) {
      return Image.memory(b, fit: BoxFit.contain, cacheWidth: 400, gaplessPlayback: true, errorBuilder: (_, __, ___) => _ph());
    }
    if (card.isNetworkImage) {
      return Image.network(card.image, fit: BoxFit.contain, errorBuilder: (_, __, ___) => _ph());
    }
    return _ph();
  }
}
