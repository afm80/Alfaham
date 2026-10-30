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
dart run flutter_launcher_icons
echo "تم. شغّل: flutter run   أو   flutter build apk --release"
