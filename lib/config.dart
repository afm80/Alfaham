/// نفس إعدادات مشروع الويب (adminafm).
class AppConfig {
  static const apiKey = 'AIzaSyDjHeOHBU-Ttrq5zsdigfPUg3b-NGzkQIU';
  static const dbUrl = 'https://adminafm-default-rtdb.firebaseio.com';

  /// الأصل (Origin) الذي تعمل عليه لوحات التحكم داخل التطبيق.
  /// هو نفس نطاق موقع الويب الحالي حتى تتصرف كل لوحة تماماً كما كانت تتصرف هناك.
  static const webOrigin = 'https://adminafm.web.app';
}
