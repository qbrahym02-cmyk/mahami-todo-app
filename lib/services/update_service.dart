import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../app_config.dart';

/// معلومات إصدار جديد منشور على GitHub Releases.
class UpdateInfo {
  final String version;
  final String notes;
  final String apkUrl;
  final String? sha256;
  final int sizeBytes;

  const UpdateInfo({
    required this.version,
    required this.notes,
    required this.apkUrl,
    this.sha256,
    this.sizeBytes = 0,
  });

  String get sizeLabel => sizeBytes <= 0
      ? ''
      : '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class UpdateService {
  String? _currentVersion;

  Future<String> currentVersion() async {
    if (_currentVersion != null) return _currentVersion!;
    final info = await PackageInfo.fromPlatform();
    _currentVersion = info.version;
    return _currentVersion!;
  }

  /// التحديث الذاتي (تنزيل APK وتثبيته) يعمل على أندرويد فقط.
  /// نسخة الويب تتحدّث تلقائياً عند كل نشر.
  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// يفحص GitHub Releases ويرجع معلومات التحديث إن وُجد إصدار أحدث.
  Future<UpdateInfo?> checkForUpdate() async {
    if (!isSupported) return null;
    try {
      final res = await http.get(
        Uri.parse(AppConfig.latestReleaseApi),
        headers: {'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;

      final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final tag = (json['tag_name'] as String? ?? '').replaceFirst('v', '');
      final current = await currentVersion();
      if (compareVersions(tag, current) <= 0) return null;

      final assets = (json['assets'] as List? ?? []).cast<Map>();
      final apk = assets.cast<Map<String, dynamic>>().firstWhere(
            (a) => (a['name'] as String? ?? '').endsWith('.apk'),
            orElse: () => {},
          );
      if (apk.isEmpty) return null;

      final digest = apk['digest'] as String?; // "sha256:...."
      return UpdateInfo(
        version: tag,
        notes: json['body'] as String? ?? '',
        apkUrl: apk['browser_download_url'] as String,
        sha256: (digest != null && digest.startsWith('sha256:'))
            ? digest.substring(7)
            : null,
        sizeBytes: (apk['size'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  /// هل نسخة المستخدم أقدم من الحد الأدنى المسموح (تحديث إجباري)؟
  Future<bool> isBelowMinimum(String minVersion) async {
    final current = await currentVersion();
    return compareVersions(current, minVersion) < 0;
  }
}

/// يقارن إصدارين بصيغة 1.2.3 — يرجع موجب إذا a أحدث.
int compareVersions(String a, String b) {
  List<int> parse(String v) => v
      .split('+')
      .first
      .split('.')
      .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
      .toList();
  final pa = parse(a), pb = parse(b);
  for (var i = 0; i < 3; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}
