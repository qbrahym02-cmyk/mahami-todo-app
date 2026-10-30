import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../app_config.dart';

/// الإعدادات القادمة من ملف remote/config.json على GitHub.
/// أي تعديل على هذا الملف يصل للتطبيق مباشرة — بدون تثبيت نسخة جديدة.
class RemoteConfig {
  final String appTitle;
  final Color primaryColor;
  final String themeMode; // system | light | dark
  final bool announcementEnabled;
  final String announcementText;
  final String announcementType; // info | success | warning
  final bool maintenanceEnabled;
  final String maintenanceMessage;
  final bool featurePriorities;
  final bool featureDueDates;
  final bool featureCategories;
  final bool featureStats;
  final List<String> categories;
  final String minSupportedVersion;
  final String emptyStateText;

  const RemoteConfig({
    this.appTitle = 'مهامي',
    this.primaryColor = const Color(0xFF6750A4),
    this.themeMode = 'system',
    this.announcementEnabled = false,
    this.announcementText = '',
    this.announcementType = 'info',
    this.maintenanceEnabled = false,
    this.maintenanceMessage = '',
    this.featurePriorities = true,
    this.featureDueDates = true,
    this.featureCategories = true,
    this.featureStats = true,
    this.categories = const ['عمل', 'شخصي', 'تسوق', 'دراسة'],
    this.minSupportedVersion = '0.0.0',
    this.emptyStateText = 'لا توجد مهام بعد — اضغط + لإضافة أول مهمة',
  });

  ThemeMode get flutterThemeMode => switch (themeMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  factory RemoteConfig.fromJson(Map<String, dynamic> j) {
    const d = RemoteConfig();
    final ann = (j['announcement'] as Map?)?.cast<String, dynamic>() ?? {};
    final maint = (j['maintenance'] as Map?)?.cast<String, dynamic>() ?? {};
    final feat = (j['features'] as Map?)?.cast<String, dynamic>() ?? {};
    return RemoteConfig(
      appTitle: j['app_title'] as String? ?? d.appTitle,
      primaryColor: _parseColor(j['primary_color'] as String?) ?? d.primaryColor,
      themeMode: j['theme_mode'] as String? ?? d.themeMode,
      announcementEnabled: ann['enabled'] as bool? ?? false,
      announcementText: ann['text'] as String? ?? '',
      announcementType: ann['type'] as String? ?? 'info',
      maintenanceEnabled: maint['enabled'] as bool? ?? false,
      maintenanceMessage: maint['message'] as String? ?? '',
      featurePriorities: feat['priorities'] as bool? ?? true,
      featureDueDates: feat['due_dates'] as bool? ?? true,
      featureCategories: feat['categories'] as bool? ?? true,
      featureStats: feat['stats'] as bool? ?? true,
      categories: (j['categories'] as List?)?.map((e) => '$e').toList() ??
          d.categories,
      minSupportedVersion:
          j['min_supported_version'] as String? ?? d.minSupportedVersion,
      emptyStateText: j['empty_state_text'] as String? ?? d.emptyStateText,
    );
  }

  static Color? _parseColor(String? hex) {
    if (hex == null) return null;
    var h = hex.replaceAll('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    final v = int.tryParse(h, radix: 16);
    return v == null ? null : Color(v);
  }
}

class RemoteConfigService extends ChangeNotifier {
  static const _cacheKey = 'remote_config_cache';
  static const _cacheTimeKey = 'remote_config_time';

  RemoteConfig _config = const RemoteConfig();
  DateTime? _lastFetched;

  RemoteConfig get config => _config;
  DateTime? get lastFetched => _lastFetched;

  /// يحمّل النسخة المخزّنة أولاً (لكي يعمل التطبيق بدون إنترنت).
  Future<void> loadCached() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    final t = prefs.getString(_cacheTimeKey);
    if (t != null) _lastFetched = DateTime.tryParse(t);
    if (raw != null) {
      try {
        _config = RemoteConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        notifyListeners();
      } catch (_) {}
    }
  }

  /// يجلب أحدث إعدادات من GitHub. يرجع true إذا تغيّر شيء.
  Future<bool> refresh() async {
    try {
      // ?t= لكسر الكاش قدر الإمكان
      final uri = Uri.parse(
          '${AppConfig.remoteConfigUrl}?t=${DateTime.now().millisecondsSinceEpoch}');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return false;
      final body = utf8.decode(res.bodyBytes);
      final parsed = RemoteConfig.fromJson(jsonDecode(body) as Map<String, dynamic>);

      final prefs = await SharedPreferences.getInstance();
      final old = prefs.getString(_cacheKey);
      _lastFetched = DateTime.now();
      await prefs.setString(_cacheKey, body);
      await prefs.setString(_cacheTimeKey, _lastFetched!.toIso8601String());

      _config = parsed;
      notifyListeners();
      return old != body;
    } catch (_) {
      return false;
    }
  }
}
