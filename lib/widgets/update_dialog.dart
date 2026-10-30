import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';

import '../services/update_service.dart';

/// نافذة التحديث: تعرض ما الجديد، ثم تنزّل التحديث وتثبّته من داخل التطبيق.
class UpdateDialog extends StatefulWidget {
  final UpdateInfo info;
  final String currentVersion;
  final bool force;

  const UpdateDialog({
    super.key,
    required this.info,
    required this.currentVersion,
    this.force = false,
  });

  static Future<void> show(
    BuildContext context, {
    required UpdateInfo info,
    required String currentVersion,
    bool force = false,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: !force,
      builder: (_) => PopScope(
        canPop: !force,
        child: UpdateDialog(
            info: info, currentVersion: currentVersion, force: force),
      ),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _working = false;
  double? _progress;
  String? _status;
  bool _error = false;

  void _start() {
    setState(() {
      _working = true;
      _error = false;
      _progress = 0;
      _status = 'جاري التنزيل...';
    });
    try {
      OtaUpdate()
          .execute(
        widget.info.apkUrl,
        destinationFilename: 'todo_update_${widget.info.version}.apk',
        sha256checksum: widget.info.sha256,
      )
          .listen((event) {
        if (!mounted) return;
        setState(() {
          switch (event.status) {
            case OtaStatus.DOWNLOADING:
              final p = double.tryParse(event.value ?? '') ?? 0;
              _progress = p / 100;
              _status = 'جاري التنزيل... ${p.toStringAsFixed(0)}%';
            case OtaStatus.INSTALLING:
              _progress = 1;
              _status = 'اضغط "تثبيت" في نافذة النظام لإكمال التحديث';
              _working = false;
            case OtaStatus.INSTALLATION_DONE:
              _status = 'تم التحديث ✓';
              _working = false;
            case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
              _fail('اسمح للتطبيق بتثبيت التطبيقات من الإعدادات ثم أعد المحاولة');
            case OtaStatus.CHECKSUM_ERROR:
              _fail('الملف تالف أو غير موثوق، أعد المحاولة');
            case OtaStatus.ALREADY_RUNNING_ERROR:
              _status = 'التنزيل قيد التشغيل بالفعل...';
            case OtaStatus.CANCELED:
              _fail('تم إلغاء التنزيل');
            default:
              _fail('تعذّر التحديث: ${event.value ?? ''}');
          }
        });
      }, onError: (e) {
        if (mounted) setState(() => _fail('تعذّر التحديث: $e'));
      });
    } catch (e) {
      setState(() => _fail('تعذّر التحديث: $e'));
    }
  }

  void _fail(String msg) {
    _working = false;
    _error = true;
    _status = msg;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = widget.info;
    return AlertDialog(
      icon: Icon(Icons.system_update, color: theme.colorScheme.primary, size: 40),
      title: Text(widget.force ? 'تحديث مطلوب' : 'يتوفر تحديث جديد'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الإصدار ${info.version}  (لديك ${widget.currentVersion})'
              '${info.sizeLabel.isEmpty ? '' : ' • ${info.sizeLabel}'}',
              style: theme.textTheme.bodySmall,
            ),
            if (widget.force) ...[
              const SizedBox(height: 8),
              Text('هذا الإصدار لم يعد مدعوماً، يجب التحديث للمتابعة.',
                  style: TextStyle(color: theme.colorScheme.error)),
            ],
            if (info.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('ما الجديد:', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(info.notes.trim()),
            ],
            if (_status != null) ...[
              const SizedBox(height: 16),
              if (_working || (_progress != null && !_error))
                LinearProgressIndicator(value: _progress),
              const SizedBox(height: 8),
              Text(_status!,
                  style: TextStyle(
                      color: _error ? theme.colorScheme.error : null)),
            ],
          ],
        ),
      ),
      actions: [
        if (!widget.force)
          TextButton(
            onPressed: _working ? null : () => Navigator.pop(context),
            child: const Text('لاحقاً'),
          ),
        FilledButton.icon(
          onPressed: _working ? null : _start,
          icon: const Icon(Icons.download),
          label: Text(_error ? 'إعادة المحاولة' : 'تحديث الآن'),
        ),
      ],
    );
  }
}
