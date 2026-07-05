import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup / Restore')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Backup database'),
            subtitle: const Text('สร้างไฟล์ SQLite backup แล้วแชร์/บันทึกลงเครื่อง'),
            onTap: () => _backup(context, ref),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restore database'),
            subtitle: const Text('เลือกไฟล์ backup และแทนที่ข้อมูลปัจจุบัน'),
            onTap: () => _restore(context, ref),
          ),
          const SizedBox(height: 12),
          const Text('Phase 2/3 จะต่อยอด OCR, import/export เพิ่มเติม, PIN, biometric, tag, recurring และ backup แบบเข้ารหัสจากโครงนี้'),
        ],
      ),
    );
  }

  Future<void> _backup(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(repositoryProvider);
    final file = await repo.createBackup();
    await repo.shareFile(file, 'Money Memo Backup');
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยัน Restore'),
        content: const Text('ข้อมูลปัจจุบันจะถูกแทนที่ด้วยไฟล์ backup ที่เลือก'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restore')),
        ],
      ),
    );
    if (ok != true) return;
    final restored = await ref.read(repositoryProvider).restoreBackup();
    if (!restored) return;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restore สำเร็จ กรุณาปิดและเปิดแอปใหม่')));
    }
  }
}
