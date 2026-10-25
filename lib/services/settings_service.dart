import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final SettingsService instance = SettingsService._internal();

  SettingsService._internal();

  final ValueNotifier<bool> isDarkMode = ValueNotifier<bool>(true);

  final ValueNotifier<bool> notificationsEnabled = ValueNotifier<bool>(true);

  final ValueNotifier<bool> workoutReminderEnabled = ValueNotifier<bool>(true);

  final ValueNotifier<bool> onboardingCompleted = ValueNotifier<bool>(false);

  SharedPreferences? _preferences;

  Future<void> load() async {
    _preferences = await SharedPreferences.getInstance();

    isDarkMode.value = _preferences?.getBool('dark_mode') ?? true;

    notificationsEnabled.value = _preferences?.getBool('notifications') ?? true;

    workoutReminderEnabled.value =
        _preferences?.getBool('workout_reminder') ?? true;

    onboardingCompleted.value =
        _preferences?.getBool('onboarding_completed') ?? false;
  }

  Future<void> setDarkMode(bool value) async {
    isDarkMode.value = value;

    await _preferences?.setBool('dark_mode', value);
  }

  Future<void> setNotifications(bool value) async {
    notificationsEnabled.value = value;

    await _preferences?.setBool('notifications', value);

    if (!value) {
      await setWorkoutReminder(false);
    }
  }

  Future<void> setWorkoutReminder(bool value) async {
    workoutReminderEnabled.value = value;

    await _preferences?.setBool('workout_reminder', value);
  }

  Future<void> completeOnboarding() async {
    onboardingCompleted.value = true;

    await _preferences?.setBool('onboarding_completed', true);
  }

  Future<void> resetSettings() async {
    await setDarkMode(true);
    await setNotifications(true);
    await setWorkoutReminder(true);
  }
}
