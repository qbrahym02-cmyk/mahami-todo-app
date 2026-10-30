import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/todo.dart';

/// تخزين المهام محلياً على الجهاز.
/// المهام لا تُحذف عند تحديث التطبيق (لأن التحديث يُثبَّت فوق النسخة القديمة
/// بنفس مفتاح التوقيع).
class TodoStorage {
  static const _key = 'todos_v1';

  Future<List<Todo>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Todo.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<Todo> todos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(todos.map((t) => t.toJson()).toList()));
  }
}
