import 'package:flutter/material.dart';
import '../database.dart';
import 'results_screen.dart';
import 'dart:async';
import '../services/test_progress_service.dart';
import 'dart:convert' as json; // Исправлено здесь
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui' show PointerDeviceKind;
import 'dart:math' as math;
import '../widgets/resume_test_dialog.dart';

class TestScreen extends StatefulWidget {
  final int topicId;
  final String topicTitle;
  final bool isTimerEnabled;
  final int timePerQuestion;

  const TestScreen({
    super.key,
    required this.topicId,
    required this.topicTitle,
    required this.isTimerEnabled,
    required this.timePerQuestion,
  });

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  int currentQuestionIndex = 0;
  List<Map<String, dynamic>> questions = [];
  String? selectedAnswer;
  TextEditingController answerController = TextEditingController();
  String sequenceAnswer = '';
  List<String?> userAnswers = [];
  Timer? _timer;
  int _timeLeft = 0;
  Map<String, List<String>> matchingAnswers = {};

  @override
  void initState() {
    super.initState();
    _checkForSavedState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    // Сохраняем состояние при выходе, если тест не завершен
    if (questions.isNotEmpty && currentQuestionIndex < questions.length) {
      _saveTestState();
    }
    super.dispose();
  }

  Future<void> _checkForSavedState() async {
    // Проверяем, есть ли сохраненное состояние теста
    if (await TestProgressService.hasTestState(widget.topicId)) {
      final savedState = await TestProgressService.getTestState(widget.topicId);
      if (savedState != null) {
        // Показываем диалог выбора
        await ResumeTestDialog.show(
          context: context,
          topicTitle: widget.topicTitle,
          savedState: savedState,
          onResumeTest: () => _resumeTest(savedState),
          onStartNew: () => _startNewTest(),
        );
      } else {
        _startNewTest();
      }
    } else {
      _startNewTest();
    }
  }

  void _startNewTest() async {
    await _loadQuestions();
    if (widget.isTimerEnabled) {
      _startTimer();
    }
  }

  void _resumeTest(TestState savedState) async {
    await _loadQuestions();
    
    setState(() {
      currentQuestionIndex = savedState.currentQuestionIndex;
      userAnswers = List<String?>.from(savedState.userAnswers);
      matchingAnswers = Map<String, List<String>>.from(
        savedState.matchingAnswers?.map((key, value) => MapEntry(key, List<String>.from(value))) ?? {}
      );
      
      // Восстанавливаем состояние текущего вопроса
      if (currentQuestionIndex < questions.length) {
        final question = questions[currentQuestionIndex];
        final questionType = question['question_type'] as String?;
        
        // Восстанавливаем ответ для текущего вопроса
        final currentAnswer = userAnswers[currentQuestionIndex];
        if (currentAnswer != null) {
          if (questionType == 'single_word' || questionType == 'two_words' || questionType == 'number') {
            answerController.text = currentAnswer;
          } else if (questionType == 'sequence') {
            sequenceAnswer = currentAnswer;
          } else {
            selectedAnswer = currentAnswer;
          }
        }
      }
      
      if (widget.isTimerEnabled) {
        _timeLeft = savedState.timeLeft ?? widget.timePerQuestion;
        _startTimer();
      }
    });
  }

  Future<void> _saveTestState() async {
    if (questions.isNotEmpty) {
      final testState = TestState(
        currentQuestionIndex: currentQuestionIndex,
        userAnswers: userAnswers,
        matchingAnswers: matchingAnswers,
        timeLeft: _timeLeft,
        savedAt: DateTime.now(),
      );
      
      await TestProgressService.saveTestState(widget.topicId, testState);
    }
  }

  void _startTimer() {
    _timeLeft = widget.timePerQuestion;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          _timer?.cancel();
          _moveToNextQuestion();
        }
      });
    });
  }

  Future<void> _loadQuestions() async {
    final loadedQuestions = await DBProvider.db.getQuestionsByTopicId(
        widget.topicId);
    setState(() {
      questions = loadedQuestions;
      userAnswers = List.filled(loadedQuestions.length, null);
    });
  }

  void _saveAnswer() {
    final question = questions[currentQuestionIndex];
    final questionType = question['question_type'] as String?;

    if (questionType == 'matching') {
      userAnswers[currentQuestionIndex] = selectedAnswer;
    }
    else if (questionType == 'single_word' || questionType == 'two_words' || questionType == 'number') {
      userAnswers[currentQuestionIndex] = answerController.text.trim();
    }
    else if (questionType == 'sequence') {
      userAnswers[currentQuestionIndex] = sequenceAnswer;
    }
    else if (questionType == 'multi_choice') {
      userAnswers[currentQuestionIndex] = selectedAnswer;
    }
    else {
      userAnswers[currentQuestionIndex] = selectedAnswer;
    }
  }

  void _moveToNextQuestion() {
    _saveAnswer();
    
    // Сохраняем состояние перед переходом к следующему вопросу
    _saveTestState();
    
    if (currentQuestionIndex < questions.length - 1) {
      setState(() {
        currentQuestionIndex++;
        selectedAnswer = null;
        answerController.clear();
        sequenceAnswer = '';
        matchingAnswers.clear();
        if (widget.isTimerEnabled) {
          _startTimer();
        }
      });
    } else {
      _finishTest();
    }
  }

  void _finishTest() async {
    // Очищаем сохраненное состояние при завершении теста
    await TestProgressService.clearTestState(widget.topicId);
    
    int correctAnswers = 0;
    for (int i = 0; i < questions.length; i++) {
      final question = questions[i];

      final questionType = question['question_type'] as String?;

      if (questionType == 'matching') {
        try {
          final userAnswer = userAnswers[i];
          if (userAnswer == null) continue;

          final userMatchingAnswers = json.jsonDecode(userAnswer) as Map<String, dynamic>;
          final correctMatchingAnswers = await DBProvider.db.getMatchingAnswers(question['id']);

          bool isCorrect = true;

          // Преобразуем userAnswer в удобный для проверки формат
          Map<String, List<String>> userMatches = {};
          userMatchingAnswers.forEach((key, value) {
            if (value is List) {
              userMatches[key] = List<String>.from(value);
            } else {
              userMatches[key] = [value.toString()];
            }
          });

          // Проверяем каждое правильное соответствие
          for (var answer in correctMatchingAnswers) {
            final leftIndex = answer['left_item_index'] as String?;
            final rightIndex = answer['right_item_index'] as String?;

            if (leftIndex == null || rightIndex == null) {
              isCorrect = false;
              break;
            }
            // Проверяем, есть ли у пользователя это соответствие
            if (!userMatches.containsKey(leftIndex)) {
              isCorrect = false;
              break;
            }
            if (!userMatches[leftIndex]!.contains(rightIndex)) {
              isCorrect = false;
              break;
            }
          }

          if (isCorrect) correctAnswers++;
        } catch (e) {}
      }
      else if (questionType == 'sequence') {
        final userAnswer = userAnswers[i];
        final correctAnswer = question['correct_answer'];

        if (userAnswer != null && correctAnswer != null &&
            userAnswer.toUpperCase() == correctAnswer.toString().toUpperCase()) {
          correctAnswers++;
        }
      } else if (questionType == 'multi_choice') {
        // Для multi_choice просто сравниваем строки букв (без учета порядка)
        final userAnswer = userAnswers[i];
        final correctAnswer = question['correct_answer'];

        if (userAnswer != null && correctAnswer != null) {
          // Преобразуем ответы в наборы букв для сравнения без учета порядка
          final userLetters = userAnswer.split('')..sort();
          final correctLetters = correctAnswer.toString().split('')..sort();

          // Сравниваем отсортированные наборы букв
          if (userLetters.join() == correctLetters.join()) {
            correctAnswers++;
          }
        }
      } else {
        final userAnswer = userAnswers[i];
        final correctAnswer = question['correct_answer'];

        if (userAnswer != null && correctAnswer != null) {
          // Проверка на несколько правильных ответов
          if (correctAnswer.toString().contains('/')) {
            // Разбиваем правильный ответ на несколько вариантов
            final acceptableAnswers = correctAnswer.toString().split('/')
                .map((answer) => answer.trim().toUpperCase())
                .toList();

            // Проверяем, соответствует ли ответ пользователя любому из вариантов
            bool isAnyMatch = acceptableAnswers.contains(userAnswer.trim().toUpperCase());

            if (isAnyMatch) correctAnswers++;
          } else {
            // Обычная проверка для одного правильного ответа
            if (userAnswer.trim().toUpperCase() == correctAnswer.toString().trim().toUpperCase()) {
              correctAnswers++;
            }
          }
        }
      }
    }

    double score = questions.isEmpty ? 0 : (correctAnswers / questions.length) * 100;

    await TestProgressService.saveTestResult(widget.topicId, score);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      _createRoute(),
    );
  }

  Route _createRoute() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          ResultsScreen(
            topicTitle: widget.topicTitle,
            questions: questions,
            userAnswers: userAnswers,
          ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.ease;

        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }

  Widget _buildQuestion(Map<String, dynamic> question) {
    final questionType = question['question_type'] as String?;

    Widget? questionImage;
    if (question['image_path'] != null && question['image_path'] is String) {
      questionImage = Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        height: 200,
        width: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            question['image_path'],
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('Ошибка загрузки изображения: $error');
              return const Center(
                child: Icon(
                  Icons.image_not_supported,
                  size: 50,
                  color: Colors.grey,
                ),
              );
            },
          ),
        ),
      );
    }

    if (questionType == 'matching') {
      return FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
        future: DBProvider.db.getMatchingOptions(question['id']),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(
                  color: Colors.black,
                )
            );
          }

          final options = snapshot.data!;

          return Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Заголовок вопроса в ScrollView для обеспечения прокрутки
                Expanded(
                  flex: 1,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Заголовок вопроса
                        Text(
                          question['question_text'] ?? 'Вопрос без текста',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        if (questionImage != null)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            height: 100, // Минимальная высота
                            width: double.infinity,
                            child: questionImage,
                          ),

                        // Инструкция в более компактном виде
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Перетащите элемент слева к соответствующему элементу справа. '
                                'Если передумали - просто перетащите ещё раз в нужный элемент. '
                                'Для удаления соответствия нажмите на крестик.',
                            style: TextStyle(
                              color: Colors.black,
                              fontStyle: FontStyle.italic,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Выделяем больше места для самого сопоставления
                Expanded(
                  flex: 5,
                  child: MatchingDragDrop(
                    leftItems: options['left']!,
                    rightItems: options['right']!,
                    onMatchesChanged: (Map<String, List<String>> matches) {
                      setState(() {
                        matchingAnswers = matches;
                        // Преобразуем в формат: {"A": ["1"], "B": ["2", "3"]}
                        selectedAnswer = json.jsonEncode(matches);
                      });
                    },
                    currentMatches: matchingAnswers,
                  ),
                ),


                // Показываем текущие соответствия, если они есть
                if (matchingAnswers.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFA5D5FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.black, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Текущие соответствия:',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Используем Wrap вместо ListView для компактного размещения
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: matchingAnswers.entries.map((entry) {
                            // Находим соответствующие тексты для визуальной ясности
                            String leftText = '';
                            String rightText = '';

                            for (var item in options['left']!) {
                              if (item['item_index'] == entry.key) {
                                leftText = item['item_text'].toString();
                                if (leftText.length > 25) {
                                  leftText = leftText.substring(0, 25) + '...';
                                }
                                break;
                              }
                            }

                            for (var item in options['right']!) {
                              if (item['item_index'] == entry.value) {
                                rightText = item['item_text'].toString();
                                if (rightText.length > 25) {
                                  rightText = rightText.substring(0, 25) + '...';
                                }
                                break;
                              }
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${entry.key} → ${entry.value}',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      );
    } else if (questionType == 'single_word' || questionType == 'two_words' || questionType == 'number') {
      return SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                question['question_text'] ?? 'Вопрос без текста',
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.black,
                ),
              ),
            ),
            if (questionImage != null) questionImage,
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: TextField(
                  controller: answerController,
                  textInputAction: TextInputAction.done,
                  keyboardType: questionType == 'number' ? TextInputType.number : TextInputType.text,
                  enableSuggestions: true,
                  autocorrect: true,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: questionType == 'number' ? 'Введите число' : 'Ваш ответ',
                    labelStyle: const TextStyle(color: Colors.black),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black),
                    ),
                    hintText: questionType == 'two_words'
                        ? 'Введите два слова через пробел'
                        : 'Можно вводить ответ в любом падеже',
                    hintStyle: const TextStyle(color: Colors.black54),
                    filled: true,
                    fillColor: Colors.transparent,
                  ),
                  style: const TextStyle(color: Colors.black),
                  cursorColor: Colors.black,
                  inputFormatters: questionType == 'number'
                      ? [FilteringTextInputFormatter.digitsOnly]
                      : null,
                ),
              ),
            ),
          ],
        ),
      );
    } else if (questionType == 'sequence') {
      // Получаем текст вопроса, который содержит варианты ответов
      final questionText = question['question_text'] as String? ?? 'Вопрос без текста';

      // Разделяем вопрос и варианты ответов
      List<String> questionParts = questionText.split('\n');
      String mainQuestion = questionParts[0];
      List<String> options = [];

      // Обрабатываем варианты ответов
      for (int i = 1; i < questionParts.length; i++) {
        final line = questionParts[i].trim();
        if (line.startsWith('А)') || line.startsWith('Б)') ||
            line.startsWith('В)') || line.startsWith('Г)') ||
            line.startsWith('Д)') || line.startsWith('Е)') ||
            line.startsWith('Ж)') || line.startsWith('З)')) {
          options.add(line);
        }
      }

      // Если варианты не найдены в тексте, создаем стандартный набор
      if (options.isEmpty) {
        options = ['А) Вариант А', 'Б) Вариант Б', 'В) Вариант В', 'Г) Вариант Г'];
      }

      return SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Text(
                    mainQuestion,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                    ),
                  ),
                  if (questionImage != null) questionImage,
                  const SizedBox(height: 16),
                  // Отображаем варианты ответов
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: options.map((option) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.2),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.black, width: 1),
                              ),
                              child: Text(
                                option.substring(0, 1),
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                option.substring(2), // Убираем букву и скобку
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Column(
                  children: [
                    for (int i = 0; i < options.length; i += 2) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildSequenceButton(options[i].substring(0, 1), i),
                          if (i + 1 < options.length) _buildSequenceButton(options[i + 1].substring(0, 1), i + 1),
                        ],
                      ),
                      if (i + 1 < options.length) const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),
            if (sequenceAnswer.isNotEmpty) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Ваша последовательность: $sequenceAnswer',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    } else if (question['options'] != null) {
      try {
        var options = json.jsonDecode(question['options'] as String);
        if (options is List && options.isNotEmpty) {
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    question['question_text'] ?? 'Вопрос без текста',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.black,
                    ),
                  ),
                ),
                if (questionImage != null) questionImage,
                const SizedBox(height: 20),
                ...options.map((option) => RadioListTile<String>(
                  title: Text(
                    option.toString(),
                    style: const TextStyle(color: Colors.black),
                  ),
                  value: option.toString(),
                  groupValue: selectedAnswer,
                  onChanged: (value) {
                    setState(() {
                      selectedAnswer = value;
                    });
                  },
                )).toList(),
              ],
            ),
          );
        }
      } catch (e) {}

      List<String> answers = [];

      if (question['correct_answer'] != null) {
        answers.add(question['correct_answer'].toString());
      }

      for (String field in ['wrong_answer1', 'wrong_answer2', 'wrong_answer3', 'wrong_answer4']) {
        if (question[field] != null) {
          answers.add(question[field].toString());
        }
      }

      if (answers.isEmpty) {
        answers.add('Ответ недоступен');
      }

      answers.shuffle();

      return SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                question['question_text'] ?? 'Вопрос без текста',
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.black,
                ),
              ),
            ),
            if (questionImage != null) questionImage,
            const SizedBox(height: 20),
            ...answers.map((answer) =>
                RadioListTile<String>(
                  title: Text(
                    answer,
                    style: const TextStyle(color: Colors.black),
                  ),
                  value: answer,
                  groupValue: selectedAnswer,
                  onChanged: (value) {
                    setState(() {
                      selectedAnswer = value;
                    });
                  },
                )),
          ],
        ),
      );
    } else if (questionType == 'multi_choice') {
      // Получаем текст вопроса, который содержит варианты ответов
      final questionText = question['question_text'] as String? ?? 'Вопрос без текста';

      // Разделяем вопрос и варианты ответов
      List<String> questionParts = questionText.split('\n');
      String mainQuestion = questionParts[0];
      List<String> options = [];

      // Извлекаем варианты ответов из текста вопроса
      for (int i = 1; i < questionParts.length; i++) {
        final line = questionParts[i].trim();
        if (line.startsWith('А)') || line.startsWith('Б)') ||
            line.startsWith('В)') || line.startsWith('Г)') ||
            line.startsWith('Д)') || line.startsWith('Е)') ||
            line.startsWith('Ж)') || line.startsWith('З)')) {
          options.add(line);
        }
      }

      // Если варианты не найдены в тексте, создаем стандартный набор
      if (options.isEmpty) {
        options = ['А) Вариант А', 'Б) Вариант Б', 'В) Вариант В', 'Г) Вариант Г'];
      }

      // Получаем выбранные пользователем буквы
      List<String> selectedLetters = [];
      if (selectedAnswer != null && selectedAnswer!.isNotEmpty) {
        selectedLetters = selectedAnswer!.split('');
      }

      return SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                mainQuestion,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.black,
                ),
              ),
            ),
            if (questionImage != null) questionImage,
            const SizedBox(height: 10),
            // Отображаем варианты ответов
            ...options.map((option) {
              String letter = option.substring(0, 1);
              bool isSelected = selectedLetters.contains(letter);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 50,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            if (isSelected) {
                              selectedLetters.remove(letter);
                            } else {
                              selectedLetters.add(letter);
                            }
                            selectedAnswer = selectedLetters.join('');
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          backgroundColor: isSelected ? Colors.grey : const Color(0xFF42A5F5),
                          foregroundColor: Colors.white,
                          shadowColor: Colors.black26,
                          elevation: 4,
                        ),
                        child: Text(
                          letter,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        option,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            if (selectedLetters.isNotEmpty) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Выбранные варианты: ${selectedLetters.join(', ')}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    } else {
      return SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                question['question_text'] ?? 'Неизвестный тип вопроса',
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.black,
                ),
              ),
            ),
            if (questionImage != null) questionImage,
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Неизвестный формат вопроса',
                style: TextStyle(color: Colors.black54),
              ),
            ),
          ],
        ),
      );
    }

    return const Center(
      child: Text(
        'Неподдерживаемый тип вопроса',
        style: TextStyle(color: Colors.black),
      ),
    );
  }

  Widget _buildSequenceButton(String letter, int _) {
    bool isSelected = sequenceAnswer.contains(letter);

    return SizedBox(
      width: 70,
      height: 70,
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            if (isSelected) {
              sequenceAnswer = sequenceAnswer.replaceAll(letter, '');
              selectedAnswer = sequenceAnswer.isEmpty ? null : sequenceAnswer;
            } else {
              // Убираем ограничение на количество букв
              sequenceAnswer += letter;
              selectedAnswer = sequenceAnswer;
            }
          });
        },
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          backgroundColor: isSelected ? Color(0xFF3D82B4) : const Color(0xFF42A5F5),
          foregroundColor: Colors.white,
          shadowColor: Colors.black26,
          elevation: 4,
        ),
        child: Text(
          letter,
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );
  }

  Widget _buildTimer() {
    int minutes = _timeLeft ~/ 60;
    int seconds = _timeLeft % 60;
    String timeString = '${minutes.toString().padLeft(2, '0')}:${seconds
        .toString().padLeft(2, '0')}';

    Color textColor = _timeLeft <= 30 ? Colors.red : Colors.black;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Text(
        timeString,
        style: TextStyle(
          fontSize: 24,
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          // Показываем диалог подтверждения выхода
          final shouldExit = await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Выйти из теста'),
              content: const Text('Что вы хотите сделать?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: () async {
                    // Сохраняем состояние и выходим
                    await _saveTestState();
                    Navigator.of(context).pop(true);
                  },
                  child: const Text('Сохранить и выйти'),
                ),
                TextButton(
                  onPressed: () async {
                    // Очищаем состояние и выходим
                    await TestProgressService.clearTestState(widget.topicId);
                    Navigator.of(context).pop(true);
                  },
                  child: const Text('Выйти без сохранения'),
                ),
              ],
            ),
          );

          return shouldExit ?? false;
        },
        child: Scaffold(
          // Убрали AppBar
          body: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: Image.asset("assets/images/backgroundfirstchapter.jpg").image,
                fit: BoxFit.cover,
              ),
            ),
            child: Column(
              children: [
                // Добавили кнопку возврата в верхний левый угол
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 40, left: 16),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black),
                      onPressed: () async {
                        final shouldExit = await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Выйти из теста'),
                            content: const Text('Что вы хотите сделать?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: const Text('Отмена'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  // Сохраняем состояние и выходим
                                  await _saveTestState();
                                  Navigator.of(context).pop(true);
                                },
                                child: const Text('Сохранить и выйти'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  // Очищаем состояние и выходим
                                  await TestProgressService.clearTestState(widget.topicId);
                                  Navigator.of(context).pop(true);
                                },
                                child: const Text('Выйти без сохранения'),
                              ),
                            ],
                          ),
                        );
                        if (shouldExit ?? false) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  ),
                ),
                // Добавили заголовок темы под кнопкой возврата
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
                  child: Text(
                    widget.topicTitle,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
                // Добавили таймер, если он включен
                if (widget.isTimerEnabled) _buildTimer(),

                questions.isEmpty
                    ? const Expanded(child: Center(child: CircularProgressIndicator()))
                    : Expanded(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                              begin: 0,
                              end: (currentQuestionIndex + 1) / questions.length,
                            ),
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeInOut,
                            builder: (context, value, _) {
                              return LinearProgressIndicator(
                                value: value,
                                backgroundColor: Colors.grey[200],
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Color(0xFF3d82b4)),
                                minHeight: 10,
                              );
                            },
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Вопрос ${currentQuestionIndex + 1}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'из ${questions.length}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Expanded(
                                child: _buildQuestion(questions[currentQuestionIndex]),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: () {
                                  _moveToNextQuestion();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF42A5F5),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  shadowColor: Colors.black26,
                                  elevation: 4,
                                ),
                                child: Text(
                                  currentQuestionIndex < questions.length - 1
                                      ? 'Следующий вопрос'
                                      : 'Проверить результаты',
                                  style: const TextStyle(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )
    );
  }
}

class MatchingDragDrop extends StatefulWidget {
  final List<Map<String, dynamic>> leftItems;
  final List<Map<String, dynamic>> rightItems;
  final Function(Map<String, List<String>>) onMatchesChanged;
  final Map<String, List<String>> currentMatches;

  const MatchingDragDrop({
    Key? key,
    required this.leftItems,
    required this.rightItems,
    required this.onMatchesChanged,
    required this.currentMatches,
  }) : super(key: key);

  @override
  State<MatchingDragDrop> createState() => _MatchingDragDropState();
}

class _MatchingDragDropState extends State<MatchingDragDrop> {
  String? _draggedItem;
  String? _hoveredTarget;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.currentMatches.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
              onPressed: () => widget.onMatchesChanged({}),
              child: const Text(
                  'Сбросить все', style: TextStyle(color: Colors.white)),
            ),
          ),

        Expanded(
          child: Row(
            children: [
              // Левая колонка - перетаскиваемые элементы
              Expanded(
                child: _buildDraggableItems(),
              ),

              // Правая колонка - цели для перетаскивания
              Expanded(
                child: _buildDropTargets(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDraggableItems() {
    return ListView.builder(
      itemCount: widget.leftItems.length,
      itemBuilder: (context, index) {
        final item = widget.leftItems[index];
        final itemIndex = item['item_index'] as String;
        final itemText = item['item_text'] as String;
        final isMatched = widget.currentMatches.containsKey(itemIndex) &&
            widget.currentMatches[itemIndex]!.isNotEmpty;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: LongPressDraggable<String>(
            data: itemIndex,
            delay: const Duration(milliseconds: 500), // Задержка для активации
            hapticFeedbackOnStart: true, // Вибрация при начале перетаскивания
            feedback: Material(
              child: Container(
                width: 200,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: _buildItemContent(itemIndex, itemText),
              ),
            ),
            childWhenDragging: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _buildItemContent(itemIndex, itemText, faded: true),
            ),
            onDragStarted: () {
              setState(() {
                _draggedItem = itemIndex;
              });
            },
            onDragEnd: (_) {
              setState(() {
                _draggedItem = null;
                _hoveredTarget = null;
              });
            },
            child: _buildItem(
              itemIndex,
              itemText,
              isMatched: isMatched,
              isLeft: true,
            ),
          ),
        );
      },
    );
  }

  Widget _buildDropTargets() {
    return ListView.builder(
      itemCount: widget.rightItems.length,
      itemBuilder: (context, index) {
        final item = widget.rightItems[index];
        final itemIndex = item['item_index'] as String;
        final itemText = item['item_text'] as String;

        // Проверяем, связана ли эта цель с каким-либо элементом
        bool isMatched = false;
        widget.currentMatches.forEach((key, values) {
          if (values.contains(itemIndex)) {
            isMatched = true;
          }
        });

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: DragTarget<String>(
            builder: (context, candidateData, rejectedData) {
              final isHighlighted = candidateData.isNotEmpty;
              final isCurrentTarget = _hoveredTarget == itemIndex;

              return _buildTargetItem(
                itemIndex,
                itemText,
                isMatched: isMatched,
                isHighlighted: isHighlighted || isCurrentTarget,
              );
            },
            onWillAccept: (data) {
              setState(() {
                _hoveredTarget = itemIndex;
              });
              return true; // Разрешаем всем элементам сопоставляться с этой целью
            },
            onAccept: (leftItemIndex) {
              final newMatches = {...widget.currentMatches};

              // Инициализируем список, если его нет
              newMatches[leftItemIndex] ??= [];

              // Если эта цель уже связана с этим элементом - удаляем связь
              if (newMatches[leftItemIndex]!.contains(itemIndex)) {
                newMatches[leftItemIndex]!.remove(itemIndex);
                // Если список целей стал пустым - удаляем элемент
                if (newMatches[leftItemIndex]!.isEmpty) {
                  newMatches.remove(leftItemIndex);
                }
              } else {
                // Добавляем новую связь
                newMatches[leftItemIndex]!.add(itemIndex);
              }

              widget.onMatchesChanged(newMatches);

              setState(() {
                _hoveredTarget = null;
              });
            },
            onLeave: (data) {
              setState(() {
                _hoveredTarget = null;
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildItem(String index, String text,
      {bool isMatched = false, bool isLeft = true}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isLeft
            ? (isMatched ? Colors.green.shade800 : Colors.green.shade500)
            : (isMatched ? Colors.blue.shade600 : Colors.blue.shade400),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isMatched
              ? (isLeft ? Colors.grey : Colors.yellow)
              : (isLeft ? Colors.green.shade700 : Colors.blue.shade700),
          width: 1,
        ),
      ),
      child: _buildItemContent(index, text),
    );
  }

  Widget _buildTargetItem(String index, String text,
      {bool isMatched = false, bool isHighlighted = false}) {
    // Более точная проверка на соответствие
    bool isActuallyMatched = false;
    widget.currentMatches.forEach((key, values) {
      if (values.contains(index)) {
        isActuallyMatched = true;
      }
    });

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActuallyMatched
            ? Colors.blue.shade600
            : (isHighlighted ? Colors.blue.shade300 : Colors.blue.shade400),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHighlighted
              ? Colors.yellow.shade700
              : (isActuallyMatched ? Colors.yellow : Colors.blue.shade700),
          width: isHighlighted ? 2 : 1,
        ),
      ),
      child: Stack(
        children: [
          _buildItemContent(index, text),
          if (isActuallyMatched)
            Positioned(
              right: 0,
              top: 0,
              child: _buildRemoveMatchButton(index),
            ),
        ],
      ),
    );
  }


  Widget _buildRemoveMatchButton(String targetIndex) {
    return GestureDetector(
      onTap: () {
        final newMatches = Map<String, List<String>>.from(
            widget.currentMatches);

        // Создаем копию ключей, чтобы избежать ошибок при изменении во время итерации
        final keys = newMatches.keys.toList();

        for (final key in keys) {
          // Удаляем цель из списка соответствий для этого элемента
          newMatches[key]!.remove(targetIndex);

          // Если список стал пустым, удаляем элемент
          if (newMatches[key]!.isEmpty) {
            newMatches.remove(key);
          }
        }

        widget.onMatchesChanged(newMatches);
      },
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.close, size: 16, color: Colors.white),
      ),
    );
  }

  Widget _buildItemContent(String index, String text, {bool faded = false}) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: faded ? Colors.grey.shade400 : Colors.black.withOpacity(0.3),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1),
          ),
          child: Text(
            index ?? '?', // Добавлена проверка на null
            style: TextStyle(
              color: faded ? Colors.grey.shade700 : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text ?? '', // Добавлена проверка на null
            style: TextStyle(
              color: faded ? Colors.grey.shade700 : Colors.white,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}