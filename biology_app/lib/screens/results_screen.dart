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
          // Проверка для заданий на сопоставление
          if (userAnswer == null) {
            results.add(false);
            continue;
          }

          final userMatchingAnswers = json.decode(userAnswer) as Map<String, dynamic>;
          final correctMatchingAnswers = await DBProvider.db.getMatchingAnswers(question['id']);
          
          bool isCorrect = true;
          if (correctMatchingAnswers.isEmpty || correctMatchingAnswers.length != userMatchingAnswers.length) {
            isCorrect = false;
          } else {
            for (var answer in correctMatchingAnswers) {
              final leftIndex = answer['left_item_index'] as String?;
              final rightIndex = answer['right_item_index'] as String?;
              
              if (leftIndex == null || rightIndex == null || !userMatchingAnswers.containsKey(leftIndex)) {
                isCorrect = false;
                break;
              }
              
              if (userMatchingAnswers[leftIndex] != rightIndex) {
                isCorrect = false;
                break;
              }
            }
          }
          results.add(isCorrect);
        } catch (e) {
          print('Ошибка при проверке ответа на вопрос с сопоставлением: $e');
          results.add(false);
        }
      } else if (questionType == 'multi_choice') {
        // Проверка для вопросов с множественным выбором
        final correctAnswer = question['correct_answer'];
        
        if (userAnswer != null && correctAnswer != null) {
          // Преобразуем ответы в наборы букв для сравнения без учета порядка
          final userLetters = userAnswer.split('')..sort();
          final correctLetters = correctAnswer.toString().split('')..sort();
          
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
            final acceptableAnswers = correctAnswer.toString().split('/');
            
            // Проверяем, соответствует ли ответ пользователя любому из вариантов
            bool isAnyMatch = acceptableAnswers.any((answer) => 
                userAnswer.trim().toUpperCase() == answer.trim().toUpperCase());
                
            results.add(isAnyMatch);
          } else {
            // Обычная проверка для одного правильного ответа
            results.add(userAnswer.trim().toUpperCase() == correctAnswer.toString().trim().toUpperCase());
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
    int correctAnswers = answerResults.where((result) => result).length;
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
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
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
                            'Правильных ответов: $correctAnswers из ${widget.questions.length}',
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
                            'Процент правильных ответов: ${percentage.toStringAsFixed(1)}%',
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
                                _getShortQuestionText(question['question_text'] ?? ''),
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
                                        question['question_text'] ?? 'Вопрос без текста',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      // Добавляем проверку на тип вопроса
                                      if (questionType == 'matching')
                                        FutureBuilder(
                                          future: _buildMatchingDetails(question, userAnswer),
                                          builder: (context, snapshot) {
                                            if (!snapshot.hasData) {
                                              return const Center(
                                                child: CircularProgressIndicator(color: Colors.white),
                                              );
                                            }
                                            return snapshot.data!;
                                          },
                                        )
                                      else
                                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: isCorrect ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                userAnswer ?? 'Нет ответа',
                                style: TextStyle(
                                                  fontSize: 14,
                                  color: isCorrect ? Colors.green : Colors.red,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                softWrap: true,
                                                overflow: TextOverflow.visible,
                                ),
                              ),
                                            const SizedBox(height: 5),
                              if (!isCorrect)
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green.withOpacity(0.2),
                                                      borderRadius: BorderRadius.circular(4),
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
      return text.split('\n').first;
    }
    // Иначе ограничиваем длину текста
    return text.length > 50 ? '${text.substring(0, 47)}...' : text;
  }

  // Отображение деталей для вопросов с сопоставлением
  Future<Widget> _buildMatchingDetails(Map<String, dynamic> question, String? userAnswer) async {
    // Получаем опции для сопоставления
    final options = await DBProvider.db.getMatchingOptions(question['id']);
    final correctAnswers = await DBProvider.db.getMatchingAnswers(question['id']);
    
    // Создаем словари для быстрого доступа к опциям
    final leftOptions = {for (var item in options['left']!) item['item_index'] as String: item['item_text'] as String};
    final rightOptions = {for (var item in options['right']!) item['item_index'] as String: item['item_text'] as String};
    
    // Создаем карту правильных ответов
    final correctMap = {for (var answer in correctAnswers) answer['left_item_index'] as String: answer['right_item_index'] as String};
    
    // Парсим пользовательский ответ
    Map<String, dynamic> userAnswersMap = {};
    if (userAnswer != null && userAnswer.isNotEmpty) {
      try {
        userAnswersMap = json.decode(userAnswer) as Map<String, dynamic>;
      } catch (e) {
        print('Ошибка при разборе ответа пользователя: $e');
      }
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
        const SizedBox(height: 5),
        ...correctMap.keys.map((leftKey) {
          final userRightKey = userAnswersMap[leftKey] as String?;
          final correctRightKey = correctMap[leftKey];
          final isMatch = userRightKey == correctRightKey;
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$leftKey) ${leftOptions[leftKey] ?? ''}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text(
                          'Ваш выбор: ',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isMatch ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              userRightKey != null 
                                  ? '$userRightKey) ${rightOptions[userRightKey] ?? ''}'
                                  : 'Не выбрано',
                              style: TextStyle(
                                color: isMatch ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              softWrap: true,
                              overflow: TextOverflow.visible,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (!isMatch)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0, left: 0.0),
                    child: Row(
                      children: [
                        const Text(
                          'Правильно: ',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white70,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '$correctRightKey) ${rightOptions[correctRightKey] ?? ''}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                            softWrap: true,
                            overflow: TextOverflow.visible,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
}