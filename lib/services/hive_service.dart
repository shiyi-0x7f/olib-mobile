import 'package:hive_flutter/hive_flutter.dart';

class HiveService {
  static const String settingsBoxName = 'settings';
  static const String authBoxName = 'auth';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(settingsBoxName);
    await Hive.openBox(authBoxName);
  }

  static Box get settingsBox => Hive.box(settingsBoxName);
  static Box get authBox => Hive.box(authBoxName);
}
