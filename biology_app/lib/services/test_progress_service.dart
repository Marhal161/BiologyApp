import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// Модель для сохранения состояния теста
class TestState {
  final int currentQuestionIndex;
  final List<String?> userAnswers;
  final Map<String, dynamic>? matchingAnswers;
  final int? timeLeft;
  final DateTime savedAt;

  TestState({
    required this.currentQuestionIndex,
    required this.userAnswers,
    this.matchingAnswers,
    this.timeLeft,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'currentQuestionIndex': currentQuestionIndex,
      'userAnswers': userAnswers,
      'matchingAnswers': matchingAnswers,
      'timeLeft': timeLeft,
      'savedAt': savedAt.millisecondsSinceEpoch,
    };
  }

  factory TestState.fromJson(Map<String, dynamic> json) {
    return TestState(
      currentQuestionIndex: json['currentQuestionIndex'] ?? 0,
      userAnswers: List<String?>.from(json['userAnswers'] ?? []),
      matchingAnswers: json['matchingAnswers'],
      timeLeft: json['timeLeft'],
      savedAt: DateTime.fromMillisecondsSinceEpoch(json['savedAt'] ?? 0),
    );
  }
}

class TestProgressService {
  static const String _keyPrefix = 'test_progress_';
  static const String _statePrefix = 'test_state_';
  
  // Сохранить результат теста
  static Future<void> saveTestResult(int topicId, double score) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('${_keyPrefix}${topicId}_score', score);
    await prefs.setBool('${_keyPrefix}${topicId}_completed', true);
    
    // Удаляем сохраненное состояние после завершения теста
    await clearTestState(topicId);
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
  
  // Сохранить состояние незавершенного теста
  static Future<void> saveTestState(int topicId, TestState state) async {
    final prefs = await SharedPreferences.getInstance();
    final stateJson = jsonEncode(state.toJson());
    await prefs.setString('${_statePrefix}${topicId}', stateJson);
  }
  
  // Получить сохраненное состояние теста
  static Future<TestState?> getTestState(int topicId) async {
    final prefs = await SharedPreferences.getInstance();
    final stateJson = prefs.getString('${_statePrefix}${topicId}');
    
    if (stateJson == null) return null;
    
    try {
      final stateMap = jsonDecode(stateJson) as Map<String, dynamic>;
      return TestState.fromJson(stateMap);
    } catch (e) {
      // Если данные повреждены, удаляем их
      await clearTestState(topicId);
      return null;
    }
  }
  
  // Проверить, есть ли сохраненное состояние теста
  static Future<bool> hasTestState(int topicId) async {
    final state = await getTestState(topicId);
    return state != null;
  }
  
  // Удалить сохраненное состояние теста
  static Future<void> clearTestState(int topicId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${_statePrefix}${topicId}');
  }
  
  // Очистить все данные о прогрессе
  static Future<void> clearAllProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (var key in keys) {
      if (key.startsWith(_keyPrefix) || key.startsWith(_statePrefix)) {
        await prefs.remove(key);
      }
    }
  }
} 