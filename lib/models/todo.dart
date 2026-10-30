enum Priority { low, medium, high }

extension PriorityX on Priority {
  String get label => switch (this) {
        Priority.low => 'منخفضة',
        Priority.medium => 'متوسطة',
        Priority.high => 'عالية',
      };
}

class Todo {
  final String id;
  final String title;
  final String note;
  final bool done;
  final Priority priority;
  final String? category;
  final DateTime? dueDate;
  final DateTime createdAt;

  const Todo({
    required this.id,
    required this.title,
    this.note = '',
    this.done = false,
    this.priority = Priority.medium,
    this.category,
    this.dueDate,
    required this.createdAt,
  });

  bool get isOverdue {
    if (done || dueDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return dueDate!.isBefore(today);
  }

  Todo copyWith({
    String? title,
    String? note,
    bool? done,
    Priority? priority,
    String? category,
    bool clearCategory = false,
    DateTime? dueDate,
    bool clearDueDate = false,
  }) {
    return Todo(
      id: id,
      title: title ?? this.title,
      note: note ?? this.note,
      done: done ?? this.done,
      priority: priority ?? this.priority,
      category: clearCategory ? null : (category ?? this.category),
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'note': note,
        'done': done,
        'priority': priority.index,
        'category': category,
        'dueDate': dueDate?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory Todo.fromJson(Map<String, dynamic> json) {
    final p = (json['priority'] as num?)?.toInt() ?? 1;
    return Todo(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      note: json['note'] as String? ?? '',
      done: json['done'] as bool? ?? false,
      priority: Priority.values[p.clamp(0, Priority.values.length - 1)],
      category: json['category'] as String?,
      dueDate: DateTime.tryParse(json['dueDate'] as String? ?? ''),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
