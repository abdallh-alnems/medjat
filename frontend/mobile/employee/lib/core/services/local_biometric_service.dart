import 'package:local_auth/local_auth.dart';

// The device-biometric gate for self check-in/out.
//
// What it proves: whoever tapped can unlock this handset. That is exactly the
// buddy-punching case — a colleague holding an already-signed-in phone — and
// nothing beyond it. It does NOT establish identity against an enrolled
// template; `face_selfie` is the method that does, and only the server decides
// there. Consistent with the project rule that the client's verdict is never
// trusted, this result is advisory: the server rejects a check-in that arrives
// without the flag when the company requires it, but a patched build could
// still send it. The gate raises the cost of cheating; it does not remove it.

enum LocalBiometricOutcome {
  /// The user passed the prompt.
  passed,

  /// The user was shown the prompt and failed or dismissed it.
  refused,

  /// No biometric or device credential is usable on this handset.
  unavailable,
}

class LocalBiometricResult {
  final LocalBiometricOutcome outcome;

  const LocalBiometricResult(this.outcome);

  bool get passed => outcome == LocalBiometricOutcome.passed;
}

class LocalBiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// True when the handset can run the prompt at all — either a enrolled
  /// biometric or, failing that, the device PIN/pattern/passcode.
  static Future<bool> isAvailable() async {
    try {
      if (await _auth.isDeviceSupported()) {
        return true;
      }
      return await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  /// Raises the system prompt. [reason] is shown to the user on iOS and in the
  /// Android prompt subtitle, so it must be localized by the caller.
  static Future<LocalBiometricResult> authenticate(String reason) async {
    if (!await isAvailable()) {
      return const LocalBiometricResult(LocalBiometricOutcome.unavailable);
    }

    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          // Deliberately leaving biometricOnly at its default (false): a handset
          // whose sensor is broken, or an employee whose fingerprint stopped
          // reading — common on manual workers' hands — falls back to the device
          // PIN rather than being locked out of recording attendance entirely.
          stickyAuth: true,
        ),
      );
      return LocalBiometricResult(
        ok ? LocalBiometricOutcome.passed : LocalBiometricOutcome.refused,
      );
    } catch (_) {
      // Covers the platform exceptions: no hardware, nothing enrolled, locked
      // out after too many attempts. Treated as unavailable so the caller can
      // decide, rather than silently reading as a refusal.
      return const LocalBiometricResult(LocalBiometricOutcome.unavailable);
    }
  }
}
