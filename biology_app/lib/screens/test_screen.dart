import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:ui' show PointerDeviceKind;
import 'dart:math' as math;
import 'dart:convert';
import '../database.dart';
import 'results_screen.dart';
import '../services/test_progress_service.dart';

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
  List<Map<String, dynamic>> questions = [];
  List<String?> userAnswers = [];
  int currentQuestionIndex = 0;
  Timer? _timer;
  int _timeLeft = 0;
  Map<String, List<String>> matchingAnswers = {};

  @override
  void initState() {
    super.initState();
    _loadQuestions();
    if (widget.isTimerEnabled) {
      _timeLeft = widget.timePerQuestion;
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.isTimerEnabled) {
      _timeLeft = widget.timePerQuestion;
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
  }

  Future<void> _loadQuestions() async {
    final loadedQuestions = await DBProvider.db.getQuestionsByTopicId(widget.topicId);
    setState(() {
      questions = loadedQuestions;
      userAnswers = List.filled(loadedQuestions.length, null);
    });
  }

  void _saveAnswer() {
    if (currentQuestionIndex < questions.length) {
      setState(() {
        userAnswers[currentQuestionIndex] = _getCurrentAnswer();
      });
    }
  }

  String? _getCurrentAnswer() {
    // Реализация получения текущего ответа
    return null;
  }

  void _moveToNextQuestion() {
    _saveAnswer();
    if (currentQuestionIndex < questions.length - 1) {
      setState(() {
        currentQuestionIndex++;
        if (widget.isTimerEnabled) {
          _timeLeft = widget.timePerQuestion;
          _startTimer();
        }
      });
    } else {
      _finishTest();
    }
  }

  void _finishTest() {
    _saveAnswer();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ResultsScreen(
          topicTitle: widget.topicTitle,
          questions: questions,
          userAnswers: userAnswers,
        ),
      ),
    ).then((_) {
      // Сохраняем результат теста
      final correctAnswers = userAnswers.where((answer) => answer != null).length;
      final score = (correctAnswers / questions.length) * 100;
      TestProgressService.saveTestResult(widget.topicId, score);
    });
  }

  Widget _buildQuestion(Map<String, dynamic> question) {
    // Реализация построения вопроса
    return Container();
  }

  Widget _buildTimer() {
    if (!widget.isTimerEnabled) return const SizedBox.shrink();
    
    int minutes = _timeLeft ~/ 60;
    int seconds = _timeLeft % 60;
    String timeString = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    Color textColor = _timeLeft <= 30 ? Colors.red : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        timeString,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textColor,
          shadows: [
            Shadow(
              color: Colors.black26,
              offset: const Offset(0, 2),
              blurRadius: 10,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        bool? shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Выйти из теста?'),
            content: const Text('Ваши ответы не будут сохранены.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Выйти'),
              ),
            ],
          ),
        );
        return shouldPop ?? false;
      },
      child: Scaffold(
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
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF2F642D), Color(0xFF5A9647)],
            ),
          ),
          child: questions.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : Column(
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
                              color: Colors.white70,
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
                    _buildTimer(),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: _buildQuestion(questions[currentQuestionIndex]),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton(
                        onPressed: _moveToNextQuestion,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2F642D),
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(
                          currentQuestionIndex < questions.length - 1 ? 'Следующий вопрос' : 'Завершить тест',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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
}