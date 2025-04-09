import 'package:flutter/material.dart';
import 'topic_screen.dart'; // Импортируем TopicScreen
import 'dart:convert';
import '../database.dart';

class ResultsScreen extends StatefulWidget {
  final String topicTitle;
  final List<Map<String, dynamic>> questions;
  final List<String?> userAnswers;

  const ResultsScreen({
    super.key,
    required this.topicTitle,
    required this.questions,
    required this.userAnswers,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  List<bool> answerResults = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAnswers();
  }

  Future<void> _checkAnswers() async {
    List<bool> results = [];

    for (int i = 0; i < widget.questions.length; i++) {
      final question = widget.questions[i];
      final userAnswer = widget.userAnswers[i];
      final questionType = question['question_type'] as String?;

      if (questionType == 'matching') {
        try {
          if (userAnswer == null) {
            results.add(false);
            continue;
          }

          final userMatchingAnswers = json.decode(userAnswer) as Map<
              String,
              dynamic>;
          final correctMatchingAnswers = await DBProvider.db.getMatchingAnswers(
              question['id']);

          bool isCorrect = true;
          // Проверяем что количество соответствий совпадает
          if (correctMatchingAnswers.length != userMatchingAnswers.length) {
            isCorrect = false;
          } else {
            // Проверяем каждое соответствие
            for (var correctPair in correctMatchingAnswers) {
              final leftIndex = correctPair['left_item_index']
                  ?.toString(); // Приводим к строке
              final rightIndex = correctPair['right_item_index']
                  ?.toString(); // Приводим к строке

              // Проверяем есть ли такой ключ у пользователя
              if (leftIndex == null || rightIndex == null ||
                  !userMatchingAnswers.containsKey(leftIndex)) {
                isCorrect = false;
                break;
              }

              // Получаем ответ пользователя (может быть строкой или списком)
              dynamic userAnswerForLeft = userMatchingAnswers[leftIndex];

              // Если ответ пользователя - список, проверяем содержит ли он правильный ответ
              if (userAnswerForLeft is List) {
                if (!userAnswerForLeft.contains(rightIndex)) {
                  isCorrect = false;
                  break;
                }
              }
              // Если ответ пользователя - строка, просто сравниваем
              else if (userAnswerForLeft.toString() != rightIndex) {
                isCorrect = false;
                break;
              }
            }
          }
          results.add(isCorrect);
        } catch (e) {
          results.add(false);
        }
      } else if (questionType == 'multi_choice') {
        // Проверка для вопросов с множественным выбором
        final correctAnswer = question['correct_answer'];

        if (userAnswer != null && correctAnswer != null) {
          // Преобразуем ответы в наборы букв для сравнения без учета порядка
          final userLetters = userAnswer.split('')
            ..sort();
          final correctLetters = correctAnswer.toString().split('')
            ..sort();

          // Сравниваем отсортированные наборы букв
          results.add(userLetters.join() == correctLetters.join());
        } else {
          results.add(false);
        }
      } else {
        // Проверка для обычных вопросов (single_word, two_words, number)
        final correctAnswer = question['correct_answer'];

        if (userAnswer != null && correctAnswer != null) {
          // Проверяем, содержит ли правильный ответ символ "/"
          if (correctAnswer.toString().contains('/')) {
            // Разбиваем правильный ответ на несколько вариантов
            final acceptableAnswers = correctAnswer.toString().split('/')
                .map((answer) => answer.trim().toUpperCase())
                .toList();

            // Проверяем, соответствует ли ответ пользователя любому из вариантов
            bool isAnyMatch = acceptableAnswers.contains(userAnswer.trim().toUpperCase());
            results.add(isAnyMatch);
          } else {
            // Обычная проверка для одного правильного ответа
            results.add(userAnswer.trim().toUpperCase() ==
                correctAnswer.toString().trim().toUpperCase());
          }
        } else {
          results.add(false);
        }
      }
    }

    setState(() {
      answerResults = results;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Подсчет правильных ответов
    int correctAnswers = answerResults
        .where((result) => result)
        .length;
    double percentage = widget.questions.isEmpty
        ? 0
        : (correctAnswers / widget.questions.length) * 100;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.topicTitle,
          style: const TextStyle(
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.black26,
                offset: Offset(0, 2),
                blurRadius: 10,
              ),
            ],
          ),
        ),
        backgroundColor: const Color(0xFF2F642D),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            colors: [Color(0xFF2F642D), Color(0xFF5A9647)],
            focal: Alignment.topRight,
            radius: 3.0,
          ),
        ),
        child: isLoading
            ? const Center(
            child: CircularProgressIndicator(color: Colors.white))
            : Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Результаты теста
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Результаты теста',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            offset: Offset(0, 2),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Правильных ответов: $correctAnswers из ${widget.questions
                          .length}',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            offset: Offset(0, 2),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Процент правильных ответов: ${percentage.toStringAsFixed(
                          1)}%',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            offset: Offset(0, 2),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Список вопросов и ответов
              Expanded(
                child: ListView.builder(
                  itemCount: widget.questions.length,
                  itemBuilder: (context, index) {
                    final question = widget.questions[index];
                    final userAnswer = widget.userAnswers[index];
                    final isCorrect = answerResults[index];
                    final questionType = question['question_type'] as String?;

                    return Card(
                      color: Colors.white.withOpacity(0.1),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ExpansionTile(
                        collapsedIconColor: Colors.white,
                        iconColor: Colors.white,
                        leading: Icon(
                          isCorrect ? Icons.check_circle : Icons.cancel,
                          color: isCorrect ? Colors.green : Colors.red,
                          size: 28,
                        ),
                        title: Text(
                          'Вопрос ${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          _getShortQuestionText(
                              question['question_text'] ?? ''),
                          style: const TextStyle(
                            color: Colors.white70,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        expandedCrossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  question['question_text'] ??
                                      'Вопрос без текста',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                // Добавляем проверку на тип вопроса
                                if (questionType == 'matching')
                                  FutureBuilder(
                                    future: _buildMatchingDetails(
                                        question, userAnswer),
                                    builder: (context, snapshot) {
                                      if (!snapshot.hasData) {
                                        return const Center(
                                          child: CircularProgressIndicator(
                                              color: Colors.white),
                                        );
                                      }
                                      return snapshot.data!;
                                    },
                                  )
                                else
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment
                                        .start,
                                    children: [
                                      const Text(
                                        'Ваш ответ:',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white70,
                                        ),
                                      ),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isCorrect ? Colors.green
                                              .withOpacity(0.2) : Colors.red
                                              .withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                              4),
                                        ),
                                        child: Text(
                                          userAnswer ?? 'Нет ответа',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: isCorrect
                                                ? Colors.green
                                                : Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          softWrap: true,
                                          overflow: TextOverflow.visible,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      if (!isCorrect)
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment
                                              .start,
                                          children: [
                                            const Text(
                                              'Правильный ответ:',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white70,
                                              ),
                                            ),
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets
                                                  .symmetric(
                                                  horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.green.withOpacity(
                                                    0.2),
                                                borderRadius: BorderRadius
                                                    .circular(4),
                                              ),
                                              child: Text(
                                                _formatCorrectAnswer(question),
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.green,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                softWrap: true,
                                                overflow: TextOverflow.visible,
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2F642D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text(
                    'Вернуться к вопросам',
                    style: TextStyle(
                      fontSize: 18,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          offset: Offset(0, 2),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Улучшенный метод форматирования ответов
  String _formatCorrectAnswer(Map<String, dynamic> question) {
    final questionType = question['question_type'] as String?;
    final correctAnswer = question['correct_answer'];

    if (questionType == null || correctAnswer == null) {
      return 'Нет правильного ответа';
    }

    if (questionType == 'multi_choice') {
      // Для вопросов с множественным выбором форматируем буквы (например, "А, Б, В")
      final letters = correctAnswer.toString().split('');
      return letters.join(', ');
    }

    if (questionType == 'matching') {
      // Этот блок не должен выполняться, так как для matching используется _buildMatchingDetails
      return 'Смотрите детали выше';
    }

    // Для вопросов с несколькими правильными ответами
    if (correctAnswer.toString().contains('/')) {
      // Заменяем "/" на "или" для более понятного отображения
      final acceptableAnswers = correctAnswer.toString().split('/')
          .map((answer) => answer.trim())
          .join(' или ');
      return acceptableAnswers;
    }

    // Для всех остальных типов вопросов
    return correctAnswer.toString();
  }

  // Получить сокращенный текст вопроса для подзаголовка
  String _getShortQuestionText(String text) {
    // Если текст содержит переносы строк, берем только первую строку
    if (text.contains('\n')) {
      return text
          .split('\n')
          .first;
    }
    // Иначе ограничиваем длину текста
    return text.length > 50 ? '${text.substring(0, 47)}...' : text;
  }

  // Отображение деталей для вопросов с сопоставлением
  Future<Widget> _buildMatchingDetails(Map<String, dynamic> question,
      String? userAnswer) async {
    try {
      // Асинхронно загружаем данные
      final optionsFuture = DBProvider.db.getMatchingOptions(question['id']);
      final correctAnswersFuture = DBProvider.db.getMatchingAnswers(
          question['id']);

      final results = await Future.wait([optionsFuture, correctAnswersFuture]);
      final options = results[0] as Map<String, List<Map<String, dynamic>>>;
      final correctAnswers = results[1] as List<Map<String, dynamic>>;

      // Быстрая проверка на пустые данные
      if (options['left'] == null || options['right'] == null ||
          correctAnswers.isEmpty) {
        return _buildErrorWidget('Данные вопроса повреждены');
      }

      // Создаем словари для быстрого доступа
      final leftOptions = {
        for (var item in options['left']!)
          item['item_index']?.toString() ?? '?': item['item_text']
              ?.toString() ?? ''
      };

      final rightOptions = {
        for (var item in options['right']!)
          item['item_index']?.toString() ?? '?': item['item_text']
              ?.toString() ?? ''
      };

      // Карта правильных ответов (учитываем множественные соответствия)
      final correctMap = <String, List<String>>{};
      for (var answer in correctAnswers) {
        final leftKey = answer['left_item_index']?.toString();
        final rightKey = answer['right_item_index']?.toString();
        if (leftKey != null && rightKey != null) {
          correctMap[leftKey] ??= [];
          correctMap[leftKey]!.add(rightKey);
        }
      }

      // Парсим ответ пользователя с защитой от ошибок
      Map<String, dynamic> userAnswersMap = {};
      if (userAnswer != null && userAnswer.isNotEmpty) {
        userAnswersMap = json.decode(userAnswer) as Map<String, dynamic>;
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ваши соответствия:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          ...correctMap.keys.map((leftKey) {
            final userRightKeys = _convertUserAnswer(userAnswersMap[leftKey]);
            final correctRightKeys = correctMap[leftKey] ?? [];
            final isMatch = _compareAnswers(userRightKeys, correctRightKeys);

            return _buildMatchRow(
              leftKey: leftKey,
              leftText: leftOptions[leftKey] ?? '',
              userRightKeys: userRightKeys,
              correctRightKeys: correctRightKeys,
              rightOptions: rightOptions,
              isMatch: isMatch,
            );
          }).toList(),
        ],
      );
    } catch (e) {
      return _buildErrorWidget('Ошибка загрузки данных');
    }
  }

// Вспомогательные методы:

  Widget _buildErrorWidget(String message) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        message,
        style: const TextStyle(color: Colors.red),
      ),
    );
  }

  List<String> _convertUserAnswer(dynamic answer) {
    if (answer == null) return [];
    if (answer is List) return answer.map((e) => e.toString()).toList();
    return [answer.toString()];
  }

  bool _compareAnswers(List<String> userAnswers, List<String> correctAnswers) {
    if (userAnswers.length != correctAnswers.length) return false;
    return userAnswers.every((answer) => correctAnswers.contains(answer));
  }

  Widget _buildMatchRow({
    required String leftKey,
    required String leftText,
    required List<String> userRightKeys,
    required List<String> correctRightKeys,
    required Map<String, String> rightOptions,
    required bool isMatch,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$leftKey) $leftText',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          _buildAnswerSection(
            title: 'Ваш выбор:',
            keys: userRightKeys,
            options: rightOptions,
            isCorrect: isMatch,
          ),
          if (!isMatch) ...[
            const SizedBox(height: 4),
            _buildAnswerSection(
              title: 'Правильно:',
              keys: correctRightKeys,
              options: rightOptions,
              isCorrect: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnswerSection({
    required String title,
    required List<String> keys,
    required Map<String, String> options,
    required bool isCorrect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        ...keys.map((key) =>
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCorrect
                      ? Colors.green.withOpacity(0.2)
                      : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$key) ${options[key] ?? ''}',
                  style: TextStyle(
                    color: isCorrect ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            )),
      ],
    );
  }
}