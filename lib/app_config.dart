/// إعدادات ثابتة للتطبيق — غيّرها إذا نقلت المستودع لمكان آخر.
class AppConfig {
  AppConfig._();

  /// صاحب مستودع GitHub واسمه (يُستخدمان لجلب الإعدادات والتحديثات).
  static const String githubOwner = 'qbrahym02-cmyk';
  static const String githubRepo = 'mahami-todo-app';
  static const String githubBranch = 'main';

  /// ملف الإعدادات عن بعد: عدّله على GitHub وسيصل التغيير للتطبيق فوراً
  /// (بدون بناء أو تثبيت أي شيء).
  static String get remoteConfigUrl =>
      'https://raw.githubusercontent.com/$githubOwner/$githubRepo/$githubBranch/remote/config.json';

  /// آخر إصدار منشور (يبنيه GitHub Actions تلقائياً عند رفع tag مثل v1.0.1).
  static String get latestReleaseApi =>
      'https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest';

  /// كل كم دقيقة نعيد فحص الإعدادات والتحديثات أثناء استخدام التطبيق.
  static const Duration recheckInterval = Duration(minutes: 15);
}
