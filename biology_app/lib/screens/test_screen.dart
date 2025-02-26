import 'package:flutter/material.dart';
import '../database.dart';
import 'results_screen.dart';
import 'dart:async';

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

  @override
  void initState() {
    super.initState();
    _loadQuestions();
    if (widget.isTimerEnabled) {
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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
    if (questions[currentQuestionIndex]['is_open_ended'] == 1) {
      userAnswers[currentQuestionIndex] = answerController.text.trim();
    } else {
      userAnswers[currentQuestionIndex] = selectedAnswer;
    }
  }

  void _moveToNextQuestion() {
    _saveAnswer();
    if (currentQuestionIndex < questions.length - 1) {
      setState(() {
        currentQuestionIndex++;
        selectedAnswer = null;
        answerController.clear();
        sequenceAnswer = '';
        if (widget.isTimerEnabled) {
          _startTimer();
        }
      });
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ResultsScreen(
                topicTitle: widget.topicTitle,
                questions: questions,
                userAnswers: userAnswers,
              ),
        ),
            (route) => route.settings.name == '/categories',
      );
    }
  }

  Widget _buildQuestion(Map<String, dynamic> question) {
    if (question['is_open_ended'] == 1) {
      return Column(
        children: [
          Text(
            question['question_text'],
            style: const TextStyle(
              fontSize: 20,
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
          const SizedBox(height: 20),
          TextField(
            controller: answerController,
            textInputAction: TextInputAction.done,
            // Закрывает клавиатуру при нажатии "Готово"
            keyboardType: TextInputType.text,
            // Разрешает ввод текста
            enableSuggestions: true,
            // Включает подсказки клавиатуры
            autocorrect: true,
            // Разрешает автокоррекцию
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Ваш ответ',
              labelStyle: TextStyle(color: Colors.white),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
            ),
            style: const TextStyle(color: Colors.white),
            cursorColor: Colors.white,
          ),
        ],
      );
    } else {
      if (question['options'] != null) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              question['question_text'],
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
            const SizedBox(height: 10),
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildSequenceButton('А', 0),
                        _buildSequenceButton('Б', 1),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildSequenceButton('В', 2),
                        _buildSequenceButton('Г', 3),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (sequenceAnswer.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Ваша последовательность: $sequenceAnswer',
                style: const TextStyle(
                  fontSize: 16,
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
          ],
        );
      } else {
        List<String> answers = [
          question['correct_answer'],
          question['wrong_answer1'],
          question['wrong_answer2'],
          question['wrong_answer3'],
          question['wrong_answer4'],
        ]
          ..shuffle(); // Перемешиваем варианты ответов

        return Column(
          children: [
            Text(
              question['question_text'],
              style: const TextStyle(
                fontSize: 20,
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
            const SizedBox(height: 20),
            ...answers.map((answer) =>
                RadioListTile<String>(
                  title: Text(
                    answer,
                    style: const TextStyle(color: Colors.white),
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
        );
      }
    }
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
              // Если буква уже выбрана, удаляем её
              sequenceAnswer = sequenceAnswer.replaceAll(letter, '');
              selectedAnswer = sequenceAnswer.isEmpty ? null : sequenceAnswer;
            } else {
              // Если буква ещё не выбрана и последовательность не полная
              if (sequenceAnswer.length < 4) {
                sequenceAnswer += letter;
                if (sequenceAnswer.length == 4) {
                  selectedAnswer = sequenceAnswer;
                }
              }
            }
          });
        },
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          backgroundColor: isSelected ? Colors.grey : const Color(0xFF2F642D),
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
    // Преобразуем оставшееся время в минуты и секунды
    int minutes = _timeLeft ~/ 60;
    int seconds = _timeLeft % 60;
    String timeString = '${minutes.toString().padLeft(2, '0')}:${seconds
        .toString().padLeft(2, '0')}';

    // Определяем цвет текста в зависимости от оставшегося времени
    Color textColor = _timeLeft <= 30 ? Colors.red : Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Text(
        timeString,
        style: TextStyle(
          fontSize: 24,
          color: textColor,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              color: Colors.black26,
              offset: Offset(0, 2),
              blurRadius: 10,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.topicTitle, style: const TextStyle(
          color: Colors.white,
          shadows: [
            Shadow(
              color: Colors.black26,
              offset: Offset(0, 2),
              blurRadius: 10,
            ),
          ],
        )),
        backgroundColor: const Color(0xFF2F642D),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (widget.isTimerEnabled) _buildTimer(),
          // Добавляем таймер в правую часть AppBar
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            colors: [Color(0xFF2F642D), Color(0xFF5A9647)],
            focal: Alignment.topRight,
            radius: 3.0,
          ),
        ),
        child: questions.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : Column(
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
                  const SizedBox(width: 8),
                  Text(
                    'из ${questions.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
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
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildQuestion(questions[currentQuestionIndex]),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        _moveToNextQuestion();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF2F642D),
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
                        style: const TextStyle(
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}