import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_config.dart';
import '../models/todo.dart';
import '../services/remote_config_service.dart';
import '../services/todo_storage.dart';
import '../services/update_service.dart';
import '../widgets/todo_editor_sheet.dart';
import '../widgets/todo_tile.dart';
import '../widgets/update_dialog.dart';

enum Filter { all, active, done }

class HomeScreen extends StatefulWidget {
  final RemoteConfigService remote;
  const HomeScreen({super.key, required this.remote});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _storage = TodoStorage();
  final _updates = UpdateService();

  List<Todo> _todos = [];
  bool _loading = true;
  Filter _filter = Filter.all;
  String? _categoryFilter;
  String _version = '';
  UpdateInfo? _pendingUpdate;
  bool _dialogOpen = false;
  DateTime _lastCheck = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _timer;

  RemoteConfig get cfg => widget.remote.config;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
    _timer = Timer.periodic(AppConfig.recheckInterval, (_) => _checkAll());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  /// عند رجوع المستخدم للتطبيق نعيد الفحص (بحد أقصى مرة كل دقيقة).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        DateTime.now().difference(_lastCheck) > const Duration(minutes: 1)) {
      _checkAll();
    }
  }

  Future<void> _init() async {
    final todos = await _storage.load();
    final v = await _updates.currentVersion();
    if (!mounted) return;
    setState(() {
      _todos = todos;
      _version = v;
      _loading = false;
    });
    _checkAll();
  }

  /// يفحص الإعدادات عن بعد + وجود إصدار جديد.
  Future<void> _checkAll({bool manual = false}) async {
    _lastCheck = DateTime.now();
    final changed = await widget.remote.refresh();
    final update = await _updates.checkForUpdate();
    if (!mounted) return;
    setState(() => _pendingUpdate = update);

    final force = await _updates.isBelowMinimum(cfg.minSupportedVersion);
    if (!mounted) return;

    if (update != null && (force || manual || !_dialogOpen)) {
      _showUpdate(update, force: force);
    } else if (manual) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(changed
            ? 'تم تطبيق الإعدادات الجديدة ✓'
            : _updates.isSupported
                ? 'أنت تستخدم أحدث إصدار ($_version) ✓'
                : 'الإعدادات محدّثة ✓'),
      ));
    }
  }

  Future<void> _showUpdate(UpdateInfo info, {bool force = false}) async {
    if (_dialogOpen) return;
    _dialogOpen = true;
    await UpdateDialog.show(context,
        info: info, currentVersion: _version, force: force);
    _dialogOpen = false;
  }

  // ---------------- عمليات المهام ----------------

  Future<void> _persist() => _storage.save(_todos);

  Future<void> _add() async {
    final t = await TodoEditorSheet.show(context, config: cfg);
    if (t == null) return;
    setState(() => _todos.insert(0, t));
    _persist();
  }

  Future<void> _edit(Todo todo) async {
    final t = await TodoEditorSheet.show(context, existing: todo, config: cfg);
    if (t == null) return;
    setState(() {
      final i = _todos.indexWhere((x) => x.id == t.id);
      if (i != -1) _todos[i] = t;
    });
    _persist();
  }

  void _toggle(Todo todo) {
    setState(() {
      final i = _todos.indexWhere((x) => x.id == todo.id);
      if (i != -1) _todos[i] = todo.copyWith(done: !todo.done);
    });
    _persist();
  }

  void _delete(Todo todo) {
    final i = _todos.indexWhere((x) => x.id == todo.id);
    if (i == -1) return;
    setState(() => _todos.removeAt(i));
    _persist();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('تم حذف "${todo.title}"'),
        action: SnackBarAction(
          label: 'تراجع',
          onPressed: () {
            setState(() => _todos.insert(i.clamp(0, _todos.length), todo));
            _persist();
          },
        ),
      ));
  }

  void _clearDone() {
    final n = _todos.where((t) => t.done).length;
    if (n == 0) return;
    setState(() => _todos.removeWhere((t) => t.done));
    _persist();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('تم حذف $n مهمة منجزة')));
  }

  List<Todo> get _visible {
    var list = _todos.where((t) => switch (_filter) {
          Filter.all => true,
          Filter.active => !t.done,
          Filter.done => t.done,
        });
    if (cfg.featureCategories && _categoryFilter != null) {
      list = list.where((t) => t.category == _categoryFilter);
    }
    final sorted = list.toList()
      ..sort((a, b) {
        if (a.done != b.done) return a.done ? 1 : -1;
        if (cfg.featurePriorities && a.priority != b.priority) {
          return b.priority.index.compareTo(a.priority.index);
        }
        return b.createdAt.compareTo(a.createdAt);
      });
    return sorted;
  }

  // ---------------- الواجهة ----------------

  @override
  Widget build(BuildContext context) {
    if (cfg.maintenanceEnabled) return _maintenance(context);

    final theme = Theme.of(context);
    final visible = _visible;

    return Scaffold(
      appBar: AppBar(
        title: Text(cfg.appTitle),
        actions: [
          if (_pendingUpdate != null)
            IconButton(
              tooltip: 'تحديث متوفر',
              onPressed: () => _showUpdate(_pendingUpdate!),
              icon: Badge(
                backgroundColor: theme.colorScheme.error,
                child: const Icon(Icons.system_update),
              ),
            ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'clear') _clearDone();
              if (v == 'check') _checkAll(manual: true);
              if (v == 'about') _about();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'check', child: Text('البحث عن تحديثات')),
              PopupMenuItem(value: 'clear', child: Text('حذف المهام المنجزة')),
              PopupMenuItem(value: 'about', child: Text('حول التطبيق')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('مهمة جديدة'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _checkAll(manual: true),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  if (cfg.announcementEnabled && cfg.announcementText.isNotEmpty)
                    SliverToBoxAdapter(child: _announcement(theme)),
                  if (cfg.featureStats && _todos.isNotEmpty)
                    SliverToBoxAdapter(child: _stats(theme)),
                  SliverToBoxAdapter(child: _filters()),
                  if (visible.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _empty(theme),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                      sliver: SliverList.separated(
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final t = visible[i];
                          return TodoTile(
                            todo: t,
                            showPriority: cfg.featurePriorities,
                            showCategory: cfg.featureCategories,
                            showDueDate: cfg.featureDueDates,
                            onToggle: () => _toggle(t),
                            onTap: () => _edit(t),
                            onDelete: () => _delete(t),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _announcement(ThemeData theme) {
    final (bg, fg, icon) = switch (cfg.announcementType) {
      'warning' => (Colors.amber.shade100, Colors.brown.shade900, Icons.warning_amber),
      'success' => (Colors.green.shade100, Colors.green.shade900, Icons.check_circle_outline),
      _ => (theme.colorScheme.primaryContainer, theme.colorScheme.onPrimaryContainer, Icons.campaign_outlined),
    };
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Icon(icon, color: fg),
        const SizedBox(width: 10),
        Expanded(child: Text(cfg.announcementText, style: TextStyle(color: fg))),
      ]),
    );
  }

  Widget _stats(ThemeData theme) {
    final total = _todos.length;
    final done = _todos.where((t) => t.done).length;
    final overdue = _todos.where((t) => t.isOverdue).length;
    final pct = total == 0 ? 0.0 : done / total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.secondaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(alignment: Alignment.center, children: [
                CircularProgressIndicator(
                  value: pct,
                  strokeWidth: 6,
                  backgroundColor: theme.colorScheme.surface,
                ),
                Text('${(pct * 100).round()}%',
                    style: theme.textTheme.labelLarge),
              ]),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('أنجزت $done من $total',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  overdue > 0
                      ? '$overdue مهمة متأخرة'
                      : (total - done == 0 ? 'أحسنت! كل المهام منجزة 🎉' : 'متبقي ${total - done}'),
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: overdue > 0 ? theme.colorScheme.error : null),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _filters() {
    final cats = cfg.featureCategories ? cfg.categories : const <String>[];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SegmentedButton<Filter>(
          segments: const [
            ButtonSegment(value: Filter.all, label: Text('الكل')),
            ButtonSegment(value: Filter.active, label: Text('النشطة')),
            ButtonSegment(value: Filter.done, label: Text('المنجزة')),
          ],
          selected: {_filter},
          onSelectionChanged: (s) => setState(() => _filter = s.first),
        ),
        if (cats.isNotEmpty) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: cats
                  .map((c) => Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: FilterChip(
                          label: Text(c),
                          selected: _categoryFilter == c,
                          onSelected: (sel) =>
                              setState(() => _categoryFilter = sel ? c : null),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _empty(ThemeData theme) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.checklist_rtl, size: 72, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              _todos.isEmpty ? cfg.emptyStateText : 'لا توجد مهام هنا',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ]),
        ),
      );

  Widget _maintenance(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.construction, size: 72),
              const SizedBox(height: 16),
              Text(
                cfg.maintenanceMessage.isEmpty
                    ? 'التطبيق تحت الصيانة حالياً'
                    : cfg.maintenanceMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () => _checkAll(manual: true),
                child: const Text('إعادة المحاولة'),
              ),
            ]),
          ),
        ),
      );

  void _about() {
    final last = widget.remote.lastFetched;
    showAboutDialog(
      context: context,
      applicationName: cfg.appTitle,
      applicationVersion: 'الإصدار $_version',
      applicationIcon: const Icon(Icons.checklist_rtl, size: 40),
      children: [
        Text(last == null
            ? 'لم يتم جلب الإعدادات عن بعد بعد.'
            : 'آخر تحديث للإعدادات: ${DateFormat.yMd('ar').add_Hm().format(last)}'),
      ],
    );
  }
}
