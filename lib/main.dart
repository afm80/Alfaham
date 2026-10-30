import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'api.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'models.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: C.bg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  try {
    final d = await rootBundle.load('assets/icon/mark.png');
    CodeFix.logoUri = 'data:image/png;base64,${base64Encode(d.buffer.asUint8List())}';
  } catch (_) {}
  await Api.i.load();
  runApp(const AlfahamApp());
}

class AlfahamApp extends StatelessWidget {
  const AlfahamApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Alfaham Admin',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Api.i.signedIn ? const HomeScreen() : const LoginScreen(),
      );
}
