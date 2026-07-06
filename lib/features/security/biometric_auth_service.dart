import 'package:local_auth/local_auth.dart';

class BiometricAuthService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isAvailable() async {
    final canCheckBiometrics = await _auth.canCheckBiometrics;
    final isDeviceSupported = await _auth.isDeviceSupported();
    final enrolled = await _auth.getAvailableBiometrics();
    return isDeviceSupported && canCheckBiometrics && enrolled.isNotEmpty;
  }

  Future<bool> authenticate() {
    return _auth.authenticate(
      localizedReason: 'ปลดล็อก Money Memo',
      biometricOnly: true,
      persistAcrossBackgrounding: true,
    );
  }
}
