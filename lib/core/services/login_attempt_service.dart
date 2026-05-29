import 'package:shared_preferences/shared_preferences.dart';

class LoginAttemptService {
  static const String _keyFailedAttempts = 'login_failed_attempts';
  static const String _keyLockoutUntil = 'login_lockout_until';

  Future<int> getFailedAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyFailedAttempts) ?? 0;
  }

  Future<void> setFailedAttempts(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFailedAttempts, count);
  }

  Future<DateTime?> getLockoutUntil() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_keyLockoutUntil);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setLockoutUntil(DateTime? time) async {
    final prefs = await SharedPreferences.getInstance();
    if (time == null) {
      await prefs.remove(_keyLockoutUntil);
    } else {
      await prefs.setInt(_keyLockoutUntil, time.millisecondsSinceEpoch);
    }
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFailedAttempts);
    await prefs.remove(_keyLockoutUntil);
  }
}