import 'package:shared_preferences/shared_preferences.dart';

class TestProgressService {
  static const String _keyPrefix = 'test_progress_';
  
  // Сохранить результат теста
  static Future<void> saveTestResult(int topicId, double score) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('${_keyPrefix}${topicId}_score', score);
    await prefs.setBool('${_keyPrefix}${topicId}_completed', true);
  }
  
  // Проверить, пройден ли тест
  static Future<bool> isTestCompleted(int topicId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('${_keyPrefix}${topicId}_completed') ?? false;
  }
  
  // Получить результат теста
  static Future<double?> getTestScore(int topicId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('${_keyPrefix}${topicId}_score');
  }
  
  // Очистить все данные о прогрессе
  static Future<void> clearAllProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (var key in keys) {
      if (key.startsWith(_keyPrefix)) {
        await prefs.remove(key);
      }
    }
  }
} 