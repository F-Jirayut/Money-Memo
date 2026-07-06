import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/app_cards.dart';
import '../transactions/transaction_providers.dart';

class SecurityScreen extends ConsumerWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appLockSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('PIN Lock')),
      body: settings.when(
        data: (data) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SwitchListTile(
              value: data.enabled,
              title: const Text('เปิด PIN lock'),
              subtitle: Text(
                data.hasPin ? 'ตั้ง PIN แล้ว' : 'ยังไม่ได้ตั้ง PIN',
              ),
              onChanged: data.hasPin
                  ? (value) =>
                        ref.read(appLockViewModelProvider).setEnabled(value)
                  : null,
            ),
            SwitchListTile(
              value: data.biometricEnabled,
              title: const Text('เปิด Biometric'),
              subtitle: const Text(
                'ใช้ fingerprint/face unlock ถ้าเครื่องรองรับ',
              ),
              onChanged: data.enabled && data.hasPin
                  ? (value) => _setBiometric(context, ref, value)
                  : null,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.password),
              title: const Text('ตั้งหรือเปลี่ยน PIN'),
              subtitle: const Text('ใช้ตัวเลข 4-6 หลัก'),
              onTap: () => _setPin(context, ref),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(message: error.toString()),
      ),
    );
  }

  Future<void> _setPin(BuildContext context, WidgetRef ref) async {
    final pin = TextEditingController();
    final confirm = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ตั้ง PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pin,
              obscureText: true,
              maxLength: 6,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'PIN',
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirm,
              obscureText: true,
              maxLength: 6,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'ยืนยัน PIN',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
    final value = pin.text.trim();
    if (ok == true && value.length >= 4 && value == confirm.text.trim()) {
      await ref.read(appLockViewModelProvider).setPin(value);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ตั้ง PIN แล้ว')));
      }
    }
  }

  Future<void> _setBiometric(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    if (!enabled) {
      await ref.read(appLockViewModelProvider).setBiometricEnabled(false);
      return;
    }
    final available = await ref
        .read(appLockViewModelProvider)
        .isBiometricAvailable();
    if (!context.mounted) return;
    if (!available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('เครื่องนี้ยังไม่มี biometric ที่พร้อมใช้'),
        ),
      );
      return;
    }
    final ok = await ref
        .read(appLockViewModelProvider)
        .authenticateWithBiometric();
    if (!context.mounted) return;
    if (ok) {
      await ref.read(appLockViewModelProvider).setBiometricEnabled(true);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('เปิด Biometric แล้ว')));
      }
    }
  }
}
