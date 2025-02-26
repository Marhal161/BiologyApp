import 'package:flutter/material.dart';
import '../database.dart';
import 'results_screen.dart';
import 'dart:async';
import 'dart:convert';

class TestScreen extends StatefulWidget {
  final int topicId;
  final String topicTitle;
  final int timePerQuestion;
  final bool isTimerEnabled;

  const TestScreen({
    super.key,
    required this.topicId,
    required this.topicTitle,
    required this.timePerQuestion,
    required this.isTimerEnabled,
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
      _timer?.cancel();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultsScreen(
            topicTitle: widget.topicTitle,
            questions: questions,
            userAnswers: userAnswers,
          ),
        ),
      );
    }
  }

  Future<void> _loadQuestions() async {
    try {
      print('Начинаю загрузку вопросов для темы с ID: ${widget.topicId}');
      
      final loadedQuestions = await DBProvider.db.getQuestionsByTopicId(widget.topicId);
      print('Загружено вопросов: ${loadedQuestions.length}');
      
      if (loadedQuestions.isEmpty) {
        print('Внимание: для темы ${widget.topicId} не найдено вопросов!');
        setState(() {
          questions = [];
        });
        return;
      }
      
      // Преобразуем результаты запроса в список, которым можно управлять
      List<Map<String, dynamic>> processedQuestions = [];
      
      // Преобразование данных из SQLite в правильный формат для отображения
      for (var originalQuestion in loadedQuestions) {
        // Создаем полную копию вопроса, чтобы избежать проблем read-only
        Map<String, dynamic> question = Map<String, dynamic>();
        originalQuestion.forEach((key, value) {
          question[key] = value;
        });
        
        print('Обработка вопроса с ID: ${question['id']}');
        print('Тип вопроса: ${question['is_open_ended'] == 1 ? "открытый" : "с вариантами"}');
        
        // Обрабатываем options только для вопросов с вариантами ответов
        if (question['is_open_ended'] == 0) {
          List<dynamic> optionsList = [];
          
          // Проверяем, есть ли options и не пустое ли оно
          if (question['options'] != null && question['options'].toString().isNotEmpty) {
            try {
              // Работаем только со строковым представлением
              String optionsString = question['options'].toString();
              var decodedOptions = json.decode(optionsString);
              optionsList = decodedOptions is List ? List<dynamic>.from(decodedOptions) : [];
              print('Успешно декодированы options: $optionsList');
            } catch (e) {
              print('Ошибка при декодировании options: $e');
              // Создаем список из строковых ответов
              optionsList = [];
              if (question['wrong_answer1'] != null && question['wrong_answer1'].toString().isNotEmpty) 
                optionsList.add(question['wrong_answer1']);
              if (question['wrong_answer2'] != null && question['wrong_answer2'].toString().isNotEmpty) 
                optionsList.add(question['wrong_answer2']);
              if (question['wrong_answer3'] != null && question['wrong_answer3'].toString().isNotEmpty) 
                optionsList.add(question['wrong_answer3']);
              if (question['wrong_answer4'] != null && question['wrong_answer4'].toString().isNotEmpty) 
                optionsList.add(question['wrong_answer4']);
              if (question['correct_answer'] != null && question['correct_answer'].toString().isNotEmpty) 
                optionsList.add(question['correct_answer']);
            }
          } else {
            // Создаем options из wrong_answers и correct_answer
            print('Options не найдены, создаем из wrong_answers и correct_answer');
            optionsList = [];
            if (question['wrong_answer1'] != null && question['wrong_answer1'].toString().isNotEmpty) 
              optionsList.add(question['wrong_answer1']);
            if (question['wrong_answer2'] != null && question['wrong_answer2'].toString().isNotEmpty) 
              optionsList.add(question['wrong_answer2']);
            if (question['wrong_answer3'] != null && question['wrong_answer3'].toString().isNotEmpty) 
              optionsList.add(question['wrong_answer3']);
            if (question['wrong_answer4'] != null && question['wrong_answer4'].toString().isNotEmpty) 
              optionsList.add(question['wrong_answer4']);
            if (question['correct_answer'] != null && question['correct_answer'].toString().isNotEmpty) 
              optionsList.add(question['correct_answer']);
          }
          
          // Присваиваем новый список, а не модифицируем существующий
          question['options'] = optionsList;
        }
        
        processedQuestions.add(question);
      }
      
      setState(() {
        questions = processedQuestions;
        userAnswers = List.filled(processedQuestions.length, null);
        if (widget.isTimerEnabled) {
          _startTimer();
        }
      });
      
      print('Вопросы успешно загружены и обработаны');
    } catch (e) {
      print('Ошибка при загрузке вопросов: $e');
      setState(() {
        questions = []; // Установить пустой список, чтобы показать сообщение об ошибке
      });
    }
  }

  void _saveAnswer() {
    if (questions[currentQuestionIndex]['is_open_ended'] == 1) {
      userAnswers[currentQuestionIndex] = answerController.text.trim();
    } else {
      userAnswers[currentQuestionIndex] = selectedAnswer;
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
            textInputAction: TextInputAction.done, // Закрывает клавиатуру при нажатии "Готово"
            keyboardType: TextInputType.text, // Разрешает ввод текста
            enableSuggestions: true, // Включает подсказки клавиатуры
            autocorrect: true, // Разрешает автокоррекцию
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
              if (sequenceAnswer.length == 4) ...[
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      sequenceAnswer = '';
                      selectedAnswer = null;
                    });
                  },
                  child: const Text('Сбросить'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF2F642D),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    shadowColor: Colors.black26,
                    elevation: 4, // Adding shadow
                  ),
                ),
              ],
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
        ]..shuffle(); // Перемешиваем варианты ответов

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
            ...answers.map((answer) => RadioListTile<String>(
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
    return SizedBox(
      width: 70,
      height: 70,
      child: ElevatedButton(
        onPressed: sequenceAnswer.contains(letter)
            ? null
            : () {
          setState(() {
            sequenceAnswer += letter;
            if (sequenceAnswer.length == 4) {
              selectedAnswer = sequenceAnswer;
            }
          });
        },
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          backgroundColor: Color(0xFF2F642D),
          foregroundColor: Colors.white,
          shadowColor: Colors.black26,
          elevation: 4, // Adding shadow to the button
        ),
        child: Text(
          letter,
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );
  }

  Widget _buildTimer() {
    if (!widget.isTimerEnabled) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          Text(
            'Осталось времени: $_timeLeft сек',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
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
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _timeLeft / widget.timePerQuestion,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                _timeLeft < 5 ? Colors.red : const Color(0xFF3d82b4)
              ),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.topicTitle,
          style: const TextStyle(color: Colors.white),
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
        child: questions.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Загрузка вопросов...',
                      style: TextStyle(
                        color: Colors.white,
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
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _loadQuestions(); // Повторная попытка загрузки
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF2F642D),
                      ),
                      child: Text('Повторить попытку'),
                    ),
                  ],
                ),
              )
            : Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                children: [
                  ClipRRect(
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
                  const SizedBox(height: 8),
                  _buildTimer(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center, // Центрируем элементы
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
                  const SizedBox(width: 8), // Добавляем небольшой отступ
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
                      onPressed: _moveToNextQuestion,
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF2F642D),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        shadowColor: Colors.black26,
                        elevation: 4, // Adding shadow to the button
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
