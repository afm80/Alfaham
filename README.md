# Alfaham Admin (Flutter)

تطبيق يجمع لوحات التحكم (HTML) في كروت. كل كرت يفتح لوحته داخل التطبيق وتقرأ بيانات مشروعها هي.
يستخدم نفس مشروع Firebase (`adminafm`) ونفس بيانات `cards`، فكروتك الحالية تظهر مباشرة.

## التشغيل (يحتاج Flutter مثبّت)
```
bash setup.sh
flutter run
flutter build apk --release
```

## بدون تثبيت Flutter
ارفع المجلد إلى GitHub، ثم Actions ← Build APK ← Run workflow، وحمّل الـ APK من Artifacts.

## ملاحظات
- لا يحتاج google-services.json؛ التطبيق يتصل بـ Firebase عبر REST.
- `lib/config.dart` فيه `webOrigin`: هو الأصل الذي تُشغَّل عليه اللوحات (نفس نطاق موقعك الحالي).
- ضغطة طويلة على الكرت: تعديل / تثبيت / حذف. زر "كرت جديد" للإضافة، وفيه زر "معاينة" قبل الحفظ.
