#!/usr/bin/env bash
# يجهّز مجلدات android/ios ويضيف الصلاحيات ويولّد أيقونة التطبيق. شغّله مرة واحدة.
set -e
if [ ! -d android ]; then
  flutter create --org com.alfaham --project-name alfaham_admin --platforms=android,ios _tmp
  cp -r _tmp/android _tmp/ios .
  rm -rf _tmp test
fi
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
echo "تم. شغّل: flutter run   أو   flutter build apk --release"
