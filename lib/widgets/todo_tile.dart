import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/todo.dart';

class TodoTile extends StatelessWidget {
  final Todo todo;
  final bool showPriority;
  final bool showCategory;
  final bool showDueDate;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const TodoTile({
    super.key,
    required this.todo,
    required this.onToggle,
    required this.onTap,
    required this.onDelete,
    this.showPriority = true,
    this.showCategory = true,
    this.showDueDate = true,
  });

  Color _priorityColor(BuildContext context) => switch (todo.priority) {
        Priority.high => Colors.red.shade400,
        Priority.medium => Colors.orange.shade400,
        Priority.low => Colors.green.shade400,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chips = <Widget>[];
    if (showCategory && todo.category != null) {
      chips.add(_Tag(icon: Icons.label_outline, text: todo.category!));
    }
    if (showDueDate && todo.dueDate != null) {
      chips.add(_Tag(
        icon: Icons.event,
        text: DateFormat.MMMd('ar').format(todo.dueDate!),
        color: todo.isOverdue ? theme.colorScheme.error : null,
      ));
    }

    return Dismissible(
      key: ValueKey(todo.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_outline, color: theme.colorScheme.onErrorContainer),
      ),
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showPriority)
                  Container(width: 5, color: _priorityColor(context)),
                Checkbox(
                  value: todo.done,
                  onChanged: (_) => onToggle(),
                  shape: const CircleBorder(),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(0, 12, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          todo.title,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            decoration:
                                todo.done ? TextDecoration.lineThrough : null,
                            color: todo.done ? theme.disabledColor : null,
                          ),
                        ),
                        if (todo.note.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(todo.note,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall),
                        ],
                        if (chips.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(spacing: 10, runSpacing: 4, children: chips),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const _Tag({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: c),
      const SizedBox(width: 3),
      Text(text, style: TextStyle(fontSize: 12, color: c)),
    ]);
  }
}
