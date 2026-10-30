#!/usr/bin/env bash
# يجهّز مجلدات android/ios ويضيف الصلاحيات ويولّد أيقونة التطبيق. شغّله مرة واحدة.
set -e
if [ ! -d android ] || [ ! -d web ]; then
  flutter create --org com.alfaham --project-name alfaham_admin --platforms=android,ios,web _tmp
  cp -r _tmp/android _tmp/ios _tmp/web .
  rm -rf _tmp test
fi

# الويب: عنوان الصفحة + service worker يمسح الـ sw.js القديم الخاص بالموقع السابق
sed -i 's|<title>[^<]*</title>|<title>Alfaham Admin</title>|' web/index.html
sed -i 's|<html>|<html lang="ar" dir="rtl">|' web/index.html
cat > web/sw.js <<'SWEOF'
self.addEventListener('install', function () { self.skipWaiting(); });
self.addEventListener('activate', function (e) {
  e.waitUntil((async function () {
    var ks = await caches.keys();
    await Promise.all(ks.map(function (k) { return caches.delete(k); }));
    await self.registration.unregister();
    var cs = await self.clients.matchAll({ type: 'window' });
    cs.forEach(function (c) { c.navigate(c.url); });
  })());
});
SWEOF
M=android/app/src/main/AndroidManifest.xml
grep -q 'android.permission.INTERNET' "$M" || sed -i 's|<application|<uses-permission android:name="android.permission.INTERNET"/>\n    <application|' "$M"
sed -i 's|android:label="[^"]*"|android:label="Alfaham Admin"|' "$M"
flutter pub get

# إصلاح: بعض الإضافات تستخدم proguard-android.txt وهو غير مدعوم في أحدث Android Gradle Plugin
CACHE="${PUB_CACHE:-$HOME/.pub-cache}"
for f in "$CACHE"/hosted/pub.dev/*/android/build.gradle "$CACHE"/hosted/pub.dev/*/android/build.gradle.kts; do
  [ -f "$f" ] && grep -q "proguard-android.txt" "$f" && sed -i "s/proguard-android\.txt/proguard-android-optimize.txt/g" "$f" && echo "patched: $f"
done
dart run flutter_launcher_icons
echo "تم. شغّل: flutter run | flutter build apk --release | flutter build web --release"
