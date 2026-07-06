import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../recurring/recurring_screen.dart';
import '../security/security_screen.dart';
import '../tags/tags_screen.dart';
import '../transactions/transaction_providers.dart';

class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('ตั้งค่า')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('PIN lock'),
            subtitle: const Text('ตั้ง PIN และเปิด/ปิดการล็อกแอป'),
            onTap: () => _push(context, const SecurityScreen()),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.sell_outlined),
            title: const Text('Tags'),
            subtitle: const Text('จัด tag สำหรับติดกับรายการรับจ่าย'),
            onTap: () => _push(context, const TagsScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.repeat),
            title: const Text('Recurring transaction'),
            subtitle: const Text('สร้างรายการประจำรายเดือน'),
            onTap: () => _push(context, const RecurringScreen()),
          ),
          Consumer(
            builder: (context, ref, _) {
              final reminder = ref.watch(reminderSettingsProvider);
              return reminder.when(
                data: (settings) => ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('แจ้งเตือนรายจ่าย'),
                  subtitle: Text(
                    settings.enabled
                        ? 'เปิดอยู่ ${_timeText(settings.hour, settings.minute)}'
                        : 'ปิดอยู่',
                  ),
                  onTap: () => _editReminder(context, ref, settings),
                ),
                loading: () => const ListTile(
                  leading: Icon(Icons.notifications_active_outlined),
                  title: Text('แจ้งเตือนรายจ่าย'),
                  subtitle: Text('กำลังโหลด'),
                ),
                error: (error, _) => ListTile(
                  leading: const Icon(Icons.notifications_off_outlined),
                  title: const Text('แจ้งเตือนรายจ่าย'),
                  subtitle: Text(error.toString()),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Backup database'),
            subtitle: const Text(
              'สร้างไฟล์ SQLite backup แล้วแชร์/บันทึกลงเครื่อง',
            ),
            onTap: () => _backup(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.enhanced_encryption_outlined),
            title: const Text('Encrypted backup'),
            subtitle: const Text('สร้างไฟล์ backup เข้ารหัสด้วยรหัสผ่าน'),
            onTap: () => _encryptedBackup(context, ref),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restore database'),
            subtitle: const Text('เลือกไฟล์ backup และแทนที่ข้อมูลปัจจุบัน'),
            onTap: () => _restore(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.lock_reset),
            title: const Text('Restore encrypted backup'),
            subtitle: const Text('เลือกไฟล์ .mmenc และใส่รหัสผ่าน'),
            onTap: () => _restoreEncrypted(context, ref),
          ),
          const SizedBox(height: 12),
          const Text(
            'Settings hub นี้รวมความปลอดภัย, แจ้งเตือน, ข้อมูลอ้างอิง และ backup ของแอป',
          ),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _backup(BuildContext context, WidgetRef ref) async {
    await ref.read(backupViewModelProvider).backup();
  }

  Future<void> _encryptedBackup(BuildContext context, WidgetRef ref) async {
    final password = await _passwordDialog(context, title: 'รหัสผ่าน Backup');
    if (password == null) return;
    await ref.read(backupViewModelProvider).encryptedBackup(password);
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยัน Restore'),
        content: const Text(
          'ข้อมูลปัจจุบันจะถูกแทนที่ด้วยไฟล์ backup ที่เลือก',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final restored = await ref.read(backupViewModelProvider).restore();
    if (!restored) return;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restore สำเร็จ กรุณาปิดและเปิดแอปใหม่')),
      );
    }
  }

  Future<void> _restoreEncrypted(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยัน Restore encrypted backup'),
        content: const Text(
          'ข้อมูลปัจจุบันจะถูกแทนที่ด้วยไฟล์ backup เข้ารหัสที่เลือก',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;
    final password = await _passwordDialog(context, title: 'รหัสผ่าน Backup');
    if (password == null) return;
    try {
      final restored = await ref
          .read(backupViewModelProvider)
          .restoreEncrypted(password);
      if (!restored) return;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Restore สำเร็จ กรุณาปิดและเปิดแอปใหม่'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Restore ไม่สำเร็จ: รหัสผ่านหรือไฟล์ไม่ถูกต้อง'),
          ),
        );
      }
    }
  }

  Future<String?> _passwordDialog(
    BuildContext context, {
    required String title,
  }) async {
    final password = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: password,
          autofocus: true,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'รหัสผ่าน'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, password.text.trim()),
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
    if (result == null || result.length < 6) {
      if (context.mounted && result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('รหัสผ่านควรมีอย่างน้อย 6 ตัวอักษร')),
        );
      }
      return null;
    }
    return result;
  }

  Future<void> _editReminder(
    BuildContext context,
    WidgetRef ref,
    ReminderSettings settings,
  ) async {
    var enabled = settings.enabled;
    var time = TimeOfDay(hour: settings.hour, minute: settings.minute);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('แจ้งเตือนรายจ่าย'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                value: enabled,
                title: const Text('เปิดแจ้งเตือนทุกวัน'),
                onChanged: (value) => setState(() => enabled = value),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule),
                title: const Text('เวลา'),
                subtitle: Text(_timeText(time.hour, time.minute)),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: time,
                  );
                  if (picked != null) {
                    setState(() => time = picked);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก'),
            ),
            TextButton(
              onPressed: () => ref.read(reminderViewModelProvider).showTest(),
              child: const Text('ทดสอบ'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      await ref
          .read(reminderViewModelProvider)
          .save(
            ReminderSettings(
              enabled: enabled,
              hour: time.hour,
              minute: time.minute,
            ),
          );
    }
  }

  String _timeText(int hour, int minute) {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}
