// يختار شاشة العرض المناسبة: WebView على الجوال، iframe على الويب.
export 'viewer_mobile.dart' if (dart.library.js_interop) 'viewer_web.dart';
