import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/todo.dart';
import '../services/remote_config_service.dart';

/// نافذة سفلية لإضافة مهمة أو تعديلها.
class TodoEditorSheet extends StatefulWidget {
  final Todo? existing;
  final RemoteConfig config;

  const TodoEditorSheet({super.key, this.existing, required this.config});

  static Future<Todo?> show(BuildContext context,
      {Todo? existing, required RemoteConfig config}) {
    return showModalBottomSheet<Todo>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => TodoEditorSheet(existing: existing, config: config),
    );
  }

  @override
  State<TodoEditorSheet> createState() => _TodoEditorSheetState();
}

class _TodoEditorSheetState extends State<TodoEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  late Priority _priority;
  String? _category;
  DateTime? _due;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _note = TextEditingController(text: e?.note ?? '');
    _priority = e?.priority ?? Priority.medium;
    _category = e?.category;
    _due = e?.dueDate;
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final e = widget.existing;
    final todo = e == null
        ? Todo(
            id: const Uuid().v4(),
            title: title,
            note: _note.text.trim(),
            priority: _priority,
            category: _category,
            dueDate: _due,
            createdAt: DateTime.now(),
          )
        : e.copyWith(
            title: title,
            note: _note.text.trim(),
            priority: _priority,
            category: _category,
            clearCategory: _category == null,
            dueDate: _due,
            clearDueDate: _due == null,
          );
    Navigator.pop(context, todo);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _due ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _due = picked);
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.config;
    final categories = {...cfg.categories, ?_category};
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.existing == null ? 'مهمة جديدة' : 'تعديل المهمة',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              autofocus: widget.existing == null,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              decoration: const InputDecoration(
                labelText: 'عنوان المهمة',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'ملاحظات (اختياري)',
                border: OutlineInputBorder(),
              ),
            ),
            if (cfg.featurePriorities) ...[
              const SizedBox(height: 16),
              Text('الأولوية', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<Priority>(
                segments: Priority.values
                    .map((p) => ButtonSegment(value: p, label: Text(p.label)))
                    .toList(),
                selected: {_priority},
                onSelectionChanged: (s) => setState(() => _priority = s.first),
              ),
            ],
            if (cfg.featureCategories && categories.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('التصنيف', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: categories
                    .map((c) => ChoiceChip(
                          label: Text(c),
                          selected: _category == c,
                          onSelected: (sel) =>
                              setState(() => _category = sel ? c : null),
                        ))
                    .toList(),
              ),
            ],
            if (cfg.featureDueDates) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.event),
                      label: Text(_due == null
                          ? 'إضافة تاريخ استحقاق'
                          : DateFormat.yMMMd('ar').format(_due!)),
                    ),
                  ),
                  if (_due != null)
                    IconButton(
                      onPressed: () => setState(() => _due = null),
                      icon: const Icon(Icons.close),
                      tooltip: 'إزالة التاريخ',
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}
