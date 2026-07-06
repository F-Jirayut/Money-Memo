import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/app_cards.dart';
import '../transactions/transaction_providers.dart';

class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> {
  final _pin = TextEditingController();
  bool _unlocked = false;
  bool _wrong = false;
  bool _biometricBusy = false;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appLockSettingsProvider);
    return settings.when(
      data: (data) {
        if (!data.enabled || !data.hasPin || _unlocked) return widget.child;
        return Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'ปลดล็อก Money Memo',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _pin,
                          autofocus: true,
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          decoration: InputDecoration(
                            labelText: 'PIN',
                            errorText: _wrong ? 'PIN ไม่ถูกต้อง' : null,
                            counterText: '',
                          ),
                          onSubmitted: (_) => _unlock(),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          icon: const Icon(Icons.lock_open),
                          label: const Text('ปลดล็อก'),
                          onPressed: _unlock,
                        ),
                        if (data.biometricEnabled) ...[
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            icon: _biometricBusy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.fingerprint),
                            label: const Text('ใช้ Biometric'),
                            onPressed: _biometricBusy
                                ? null
                                : _unlockWithBiometric,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) =>
          Scaffold(body: EmptyState(message: error.toString())),
    );
  }

  Future<void> _unlock() async {
    final ok = await ref.read(appLockViewModelProvider).verify(_pin.text);
    if (!mounted) return;
    setState(() {
      _unlocked = ok;
      _wrong = !ok;
    });
  }

  Future<void> _unlockWithBiometric() async {
    setState(() => _biometricBusy = true);
    try {
      final ok = await ref
          .read(appLockViewModelProvider)
          .authenticateWithBiometric();
      if (!mounted) return;
      setState(() {
        _unlocked = ok;
        _wrong = !ok;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _wrong = true);
    } finally {
      if (mounted) setState(() => _biometricBusy = false);
    }
  }
}
