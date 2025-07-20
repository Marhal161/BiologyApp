import 'package:flutter/material.dart';
import '../database.dart';
import 'results_screen.dart';
import 'dart:async';
import '../services/test_progress_service.dart';
import 'dart:convert' as json;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../widgets/resume_test_dialog.dart';

class TestScreen extends StatefulWidget {
  final int topicId;
  final String topicTitle;
  final bool isTimerEnabled;
  final int timePerQuestion;
  final int chapterId;

  const TestScreen({
    super.key,
    required this.topicId,
    required this.topicTitle,
    required this.isTimerEnabled,
    required this.timePerQuestion,
    required this.chapterId,
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

  String _getBackgroundImage() {
    switch (widget.chapterId) {
      case 1: return "assets/images/backgroundfirstchapter.jpg";
      case 2: return "assets/images/backgroundsecondchapter.jpg";
      case 3: return "assets/images/backgroundthirdchapter.jpg";
      case 4: return "assets/images/backgroundfourthchapter.jpg";
      default: return "assets/images/backgrounddefault.jpg";
    }
  }

  @override
  void initState() {
    super.initState();
    _checkForSavedState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (questions.isNotEmpty && currentQuestionIndex < questions.length) {
      _saveTestState();
    }
    super.dispose();
  }

  Future<void> _checkForSavedState() async {
    if (await TestProgressService.hasTestState(widget.topicId)) {
      final savedState = await TestProgressService.getTestState(widget.topicId);
      if (savedState != null) {
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
          savedState.matchingAnswers?.map((key, value) =>
              MapEntry(key, List<String>.from(value))) ?? {}
      );

      if (currentQuestionIndex < questions.length) {
        final question = questions[currentQuestionIndex];
        final questionType = question['question_type'] as String?;

        final currentAnswer = userAnswers[currentQuestionIndex];
        if (currentAnswer != null) {
          if (questionType == 'single_word' || questionType == 'two_words' ||
              questionType == 'number') {
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
    final loadedQuestions = await DBProvider.db.getQuestionsByTopicId(widget.topicId);
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
    else if (questionType == 'single_word' || questionType == 'two_words' ||
        questionType == 'number') {
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
          Map<String, List<String>> userMatches = {};
          userMatchingAnswers.forEach((key, value) {
            if (value is List) {
              userMatches[key] = List<String>.from(value);
            } else {
              userMatches[key] = [value.toString()];
            }
          });

          for (var answer in correctMatchingAnswers) {
            final leftIndex = answer['left_item_index'] as String?;
            final rightIndex = answer['right_item_index'] as String?;

            if (leftIndex == null || rightIndex == null) {
              isCorrect = false;
              break;
            }
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
        final userAnswer = userAnswers[i];
        final correctAnswer = question['correct_answer'];

        if (userAnswer != null && correctAnswer != null) {
          final userLetters = userAnswer.split('')..sort();
          final correctLetters = correctAnswer.toString().split('')..sort();

          if (userLetters.join() == correctLetters.join()) {
            correctAnswers++;
          }
        }
      } else {
        final userAnswer = userAnswers[i];
        final correctAnswer = question['correct_answer'];

        if (userAnswer != null && correctAnswer != null) {
          if (correctAnswer.toString().contains('/')) {
            final acceptableAnswers = correctAnswer.toString().split('/')
                .map((answer) => answer.trim().toUpperCase())
                .toList();

            bool isAnyMatch = acceptableAnswers.contains(userAnswer.trim().toUpperCase());

            if (isAnyMatch) correctAnswers++;
          } else {
            if (userAnswer.trim().toUpperCase() ==
                correctAnswer.toString().trim().toUpperCase()) {
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
      pageBuilder: (context, animation, secondaryAnimation) => ResultsScreen(
        topicTitle: widget.topicTitle,
        questions: questions,
        userAnswers: userAnswers,
        chapterId: widget.chapterId,
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
        height: 300, // Увеличенная высота изображения
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
            return const Center(child: CircularProgressIndicator(color: Colors.black));
          }

          final options = snapshot.data!;

          return Column(
            children: [
              // Вопрос и изображение - теперь занимают меньше места
              Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        question['question_text'] ?? 'Вопрос без текста',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (questionImage != null) questionImage,
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Перетащите элемент слева к соответствующему элементу справа. '
                              'Если передумали - просто перетащите ещё раз в нужный элемент.',
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
              const SizedBox(height: 24), // Было 8-12
              // Область для сопоставления - теперь занимает больше места
              Expanded(
                child: MatchingDragDrop(
                  leftItems: options['left']!,
                  rightItems: options['right']!,
                  onMatchesChanged: (Map<String, List<String>> matches) {
                    setState(() {
                      matchingAnswers = matches;
                      selectedAnswer = json.jsonEncode(matches);
                    });
                  },
                  currentMatches: matchingAnswers,
                ),
              ),

              // Текущие соответствия - компактнее
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
                      const Text(
                        'Текущие соответствия:',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: matchingAnswers.entries.map((entry) {
                            String leftText = '';
                            String rightText = '';

                            for (var item in options['left']!) {
                              if (item['item_index'] == entry.key) {
                                leftText = item['item_text'].toString();
                                break;
                              }
                            }

                            for (var item in options['right']!) {
                              if (item['item_index'] == entry.value) {
                                rightText = item['item_text'].toString();
                                break;
                              }
                            }

                            return Container(
                              margin: const EdgeInsets.only(right: 8),
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
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      );
    }
    else if (questionType == 'single_word' || questionType == 'two_words' || questionType == 'number') {
      return SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                question['question_text'] ?? 'Вопрос без текста',
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.black,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.2,
                  wordSpacing: 0.1,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                softWrap: true,
                textScaleFactor: 0.9,
              ),
            ),
            if (questionImage != null) questionImage,
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: answerController,
                  textInputAction: TextInputAction.done,
                  keyboardType: questionType == 'number'
                      ? TextInputType.number
                      : TextInputType.text,
                  enableSuggestions: true,
                  autocorrect: true,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    labelText: questionType == 'number'
                        ? 'Введите число'
                        : 'Ваш ответ',
                    labelStyle: const TextStyle(color: Colors.black),
                    hintText: questionType == 'two_words'
                        ? 'Введите два слова через пробел'
                        : 'Можно вводить ответ в любом падеже',
                    hintStyle: const TextStyle(color: Colors.black54),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
      final questionText = question['question_text'] as String? ?? 'Вопрос без текста';
      List<String> questionParts = questionText.split('\n');
      String mainQuestion = questionParts[0];
      List<String> options = [];

      for (int i = 1; i < questionParts.length; i++) {
        final line = questionParts[i].trim();
        if (line.startsWith('А)') || line.startsWith('Б)') ||
            line.startsWith('В)') || line.startsWith('Г)') ||
            line.startsWith('Д)') || line.startsWith('Е)')) {
          options.add(line);
        }
      }

      // Ограничиваем максимум 6 вариантов (3x2)
      options = options.take(6).toList();
      if (options.isEmpty) {
        options = ['А) Вариант А', 'Б) Вариант Б', 'В) Вариант В',
          'Г) Вариант Г', 'Д) Вариант Д', 'Е) Вариант Е'];
      }

      return LayoutBuilder(
        builder: (context, constraints) {
          final bool isSmallScreen = constraints.maxWidth < 600;
          final double buttonSize = isSmallScreen ? constraints.maxWidth / 6 : constraints.maxWidth / 6;
          final double buttonPadding = isSmallScreen ? 4.0 : 4.0;

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    children: [
                      Text(
                        mainQuestion,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 16.0 : 18.0,
                          color: Colors.black,
                          letterSpacing: -0.2,
                          wordSpacing: 0.1,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                        softWrap: true,
                        textScaleFactor: 0.9,
                      ),
                      if (questionImage != null) questionImage!,
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: options.map((option) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 30,
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${option.substring(0, 1)}:',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: isSmallScreen ? 14.0 : 16.0,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    option.substring(2),
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 14.0 : 16.0,
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
                const SizedBox(height: 16),
                // Измененная сетка для кнопок
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16.0 : 32.0),
                  child: options.length == 4
                      ? Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Padding(
                            padding: EdgeInsets.all(4), // Reduced padding from 6 to 4
                            child: SizedBox(
                              width: buttonSize,
                              height: buttonSize,
                              child: _buildSequenceButton('А', options.indexWhere((opt) => opt.startsWith('А'))),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(4), // Reduced padding from 6 to 4
                            child: SizedBox(
                              width: buttonSize,
                              height: buttonSize,
                              child: _buildSequenceButton('Б', options.indexWhere((opt) => opt.startsWith('Б'))),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Padding(
                            padding: EdgeInsets.all(4), // Reduced padding from 6 to 4
                            child: SizedBox(
                              width: buttonSize,
                              height: buttonSize,
                              child: _buildSequenceButton('В', options.indexWhere((opt) => opt.startsWith('В'))),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(4), // Reduced padding from 6 to 4
                            child: SizedBox(
                              width: buttonSize,
                              height: buttonSize,
                              child: _buildSequenceButton('Г', options.indexWhere((opt) => opt.startsWith('Г'))),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                      : Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          for (int i = 0; i < 3 && i < options.length; i++)
                            Padding(
                              padding: EdgeInsets.all(6),
                              child: SizedBox(
                                width: buttonSize,
                                height: buttonSize,
                                child: _buildSequenceButton(options[i].substring(0, 1), i),
                              ),
                            ),
                        ],
                      ),
                      if (options.length > 3)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            for (int i = 3; i < 6 && i < options.length; i++)
                              Padding(
                                padding: EdgeInsets.all(6),
                                child: SizedBox(
                                  width: buttonSize,
                                  height: buttonSize,
                                  child: _buildSequenceButton(options[i].substring(0, 1), i),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
                if (sequenceAnswer.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Ваша последовательность: $sequenceAnswer',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14.0 : 16.0,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      );
    }else if (question['options'] != null) {
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
                ...options.map((option) =>
                    RadioListTile<String>(
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

      for (String field in [
        'wrong_answer1',
        'wrong_answer2',
        'wrong_answer3',
        'wrong_answer4'
      ]) {
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
      final questionText = question['question_text'] as String? ?? 'Вопрос без текста';
      List<String> questionParts = questionText.split('\n');
      String mainQuestion = questionParts[0];
      List<String> options = [];

      for (int i = 1; i < questionParts.length; i++) {
        final line = questionParts[i].trim();
        if (line.startsWith('А)') || line.startsWith('Б)') ||
            line.startsWith('В)') || line.startsWith('Г)') ||
            line.startsWith('Д)') || line.startsWith('Е)') ||
            line.startsWith('Ж)') || line.startsWith('З)')) {
          options.add(line);
        }
      }

      if (options.isEmpty) {
        options = ['А) Вариант А', 'Б) Вариант Б', 'В) Вариант В', 'Г) Вариант Г'];
      }

      List<String> selectedLetters = [];
      if (selectedAnswer != null && selectedAnswer!.isNotEmpty) {
        selectedLetters = selectedAnswer!.split('');
      }

      return LayoutBuilder(
        builder: (context, constraints) {
          final bool isSmallScreen = constraints.maxWidth < 400;

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Text(
                      mainQuestion,
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.black,
                        letterSpacing: -0.2,
                        wordSpacing: 0.1,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                      softWrap: true,
                      textScaleFactor: 0.9,
                    ),
                  ),

                  if (questionImage != null) questionImage,

                  const SizedBox(height: 20),

                  // Адаптивное отображение вариантов ответа
                  ...options.map((option) {
                    String letter = option.substring(0, 1);
                    bool isSelected = selectedLetters.contains(letter);
                    String optionText = option.substring(2).trim();

                    return Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 8.0,
                        horizontal: isSmallScreen ? 8.0 : 16.0,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white.withOpacity(0.7),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Кнопка выбора с адаптивным размером
                            SizedBox(
                              width: isSmallScreen ? 40 : 50,
                              height: isSmallScreen ? 40 : 50,
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
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  backgroundColor: isSelected
                                      ? const Color(0xFF3D82B4)
                                      : const Color(0xFF42A5F5),
                                  foregroundColor: Colors.white,
                                  elevation: 1,
                                  side: BorderSide(
                                    color: isSelected
                                        ? const Color(0xFF3D82B4)
                                        : Colors.grey.shade400,
                                  ),
                                ),
                                child: Text(
                                  letter,
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 20 : 24,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 8),

                            // Текст ответа с адаптивными отступами
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: isSmallScreen ? 8.0 : 14.0,
                                  horizontal: 8.0,
                                ),
                                child: Text(
                                  optionText,
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 14 : 16,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),

                  if (selectedLetters.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Выбрано: ${selectedLetters.join(', ')}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
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
  }

  Widget _buildSequenceButton(String letter, int _, {double size = 70}) {
    bool isSelected = sequenceAnswer.contains(letter);

    return SizedBox(
      width: size,
      height: size,
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            if (isSelected) {
              sequenceAnswer = sequenceAnswer.replaceAll(letter, '');
              selectedAnswer = sequenceAnswer.isEmpty ? null : sequenceAnswer;
            } else {
              sequenceAnswer += letter;
              selectedAnswer = sequenceAnswer;
            }
          });
        },
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: isSelected ? const Color(0xFF3D82B4) : const Color(0xFF42A5F5),
          foregroundColor: Colors.white,
          shadowColor: Colors.black26,
          elevation: 4,
        ),
        child: Text(
          letter,
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildTimer() {
    int minutes = _timeLeft ~/ 60;
    int seconds = _timeLeft % 60;
    String timeString = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

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
        final shouldExit = await showDialog(
          context: context,
          builder: (context) =>
              AlertDialog(
                title: const Text('Выйти из теста'),
                content: const Text('Что вы хотите сделать?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Отмена'),
                  ),
                  TextButton(
                    onPressed: () async {
                      await _saveTestState();
                      Navigator.of(context).pop(true);
                    },
                    child: const Text('Сохранить и выйти'),
                  ),
                  TextButton(
                    onPressed: () async {
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
        body: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(_getBackgroundImage()),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 60, left: 16, right: 16, bottom: 8), // Уменьшен нижний отступ
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.black, size: 28),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () async {
                          final shouldExit = await showDialog(
                            context: context,
                            builder: (context) =>
                                AlertDialog(
                                  title: const Text('Выйти из теста'),
                                  content: const Text('Что вы хотите сделать?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: const Text('Отмена'),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        await _saveTestState();
                                        Navigator.of(context).pop(true);
                                      },
                                      child: const Text('Сохранить и выйти'),
                                    ),
                                    TextButton(
                                      onPressed: () async {
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.topicTitle,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            height: 1.0,
                            overflow: TextOverflow.clip,
                            wordSpacing: 0.1,// Уменьшен межстрочный интервал
                            letterSpacing: -0.2,

                          ),
                          textAlign: TextAlign.center,
                          softWrap: true,
                        ),
                      ),
                      const SizedBox(width: 40), // Добавлен для балансировки
                    ],
                  ),
                ),
                if (widget.isTimerEnabled) _buildTimer(),

                questions.isEmpty
                    ? const Expanded(child: Center(child: CircularProgressIndicator()))
                    : Expanded(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3d82b4)),
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
                              const SizedBox(height: 40),
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
          ],
        ),
      ),
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
              Expanded(
                child: _buildDraggableItems(),
              ),
              const SizedBox(width: 32),
              // Увеличенное расстояние между колонками
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
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: LongPressDraggable<String>(
            data: itemIndex,
            delay: const Duration(milliseconds: 500),
            hapticFeedbackOnStart: true,
            feedback: Opacity(
              opacity: 0.8,
              child: Container(
                width: 250,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFcce9cb),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    width: 1,
                  ),
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

        bool isMatched = false;
        widget.currentMatches.forEach((key, values) {
          if (values.contains(itemIndex)) {
            isMatched = true;
          }
        });

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          // Увеличенный вертикальный отступ
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
              return true;
            },
            onAccept: (leftItemIndex) {
              final newMatches = {...widget.currentMatches};
              newMatches[leftItemIndex] ??= [];

              if (newMatches[leftItemIndex]!.contains(itemIndex)) {
                newMatches[leftItemIndex]!.remove(itemIndex);
                if (newMatches[leftItemIndex]!.isEmpty) {
                  newMatches.remove(leftItemIndex);
                }
              } else {
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

  Widget _buildItemContent(String index, String text, {bool faded = false, bool isLeft = true}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isLeft ? const Color(0xFFcce9cb) : const Color(0xFFc8e9f8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              index ?? '?',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Colors.white.withOpacity(0.5),
                  width: 3,
                ),
              ),
            ),
            child: Text(
              text ?? '',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 14,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(String index, String text, {bool isMatched = false, bool isLeft = true}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMatched ? Colors.green.shade300 : Colors.grey.shade300,
          width: 1,
        ),
        // Убрал boxShadow для всех элементов
      ),
      child: _buildItemContent(index, text, isLeft: isLeft),
    );
  }

  Widget _buildTargetItem(String index, String text, {bool isMatched = false, bool isHighlighted = false}) {
    bool isActuallyMatched = false;
    widget.currentMatches.forEach((key, values) {
      if (values.contains(index)) {
        isActuallyMatched = true;
      }
    });

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHighlighted
              ? Colors.orange
              : (isActuallyMatched ? Colors.green : Colors.grey.shade300),
          width: isHighlighted ? 2 : 1,
        ),
        // Убрал boxShadow и для правых элементов
      ),
      child: Stack(
        children: [
          _buildItemContent(index, text, isLeft: false),
          if (isActuallyMatched)
            Positioned(
              right: 8,
              top: 8,
              child: _buildRemoveMatchButton(index),
            ),
        ],
      ),
    );
  }

  Widget _buildRemoveMatchButton(String targetIndex) {
    return GestureDetector(
      onTap: () {
        final newMatches = Map<String, List<String>>.from(widget.currentMatches);
        final keys = newMatches.keys.toList();

        for (final key in keys) {
          newMatches[key]!.remove(targetIndex);
          if (newMatches[key]!.isEmpty) {
            newMatches.remove(key);
          }
        }

        widget.onMatchesChanged(newMatches);
      },
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.2), // Серый цвет с прозрачностью
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.arrow_back, // Иконка "назад" вместо крестика
          size: 16,
          color: Colors.white,
        ),
      ),
    );
  }
  }