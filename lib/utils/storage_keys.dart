import 'package:shared_preferences/shared_preferences.dart';

/// Kunci-kunci untuk penyimpanan lokal (SharedPreferences).
abstract final class StorageKeys {
  static const onboardingCompleted = 'onboarding_completed';

  static Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(onboardingCompleted) ?? false;
  }

  static Future<void> setOnboardingCompleted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(onboardingCompleted, value);
  }
}
