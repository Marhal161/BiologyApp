import 'package:flutter/material.dart';
import '../database.dart';
import 'results_screen.dart';
import 'dart:async';
import '../services/test_progress_service.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;

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
  Map<String, String> matchingAnswers = {};

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
    int correctAnswers = 0;
    for (int i = 0; i < questions.length; i++) {
      final question = questions[i];
      
      final questionType = question['question_type'] as String?;
      
      if (questionType == 'matching') {
        try {
          final userAnswer = userAnswers[i];
          if (userAnswer == null) continue;
          
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
          if (isCorrect) correctAnswers++;
        } catch (e) {
          debugPrint('Ошибка при проверке ответа на вопрос с сопоставлением: $e');
        }
      } else if (questionType == 'sequence') {
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
            final acceptableAnswers = correctAnswer.toString().split('/');
            
            // Проверяем, соответствует ли ответ пользователя любому из вариантов
            bool isAnyMatch = acceptableAnswers.any((answer) => 
                userAnswer.trim().toUpperCase() == answer.trim().toUpperCase());
                
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
                color: Colors.white,
              )
            );
          }

          final options = snapshot.data!;
          
          // Полностью перерабатываем структуру для лучшей адаптивности
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
                            color: Colors.white,
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
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Перетащите элемент слева к соответствующему элементу справа',
                            style: TextStyle(
                              color: Colors.white,
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
                  flex: 5, // Выделяем больше места для сопоставления
                  child: MatchingDragDrop(
                    leftItems: options['left']!,
                    rightItems: options['right']!,
                    onMatchesChanged: (matches) {
                      setState(() {
                        matchingAnswers = matches;
                        selectedAnswer = json.encode(matchingAnswers);
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
                      color: const Color(0xFF2F642D),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Текущие соответствия:',
                              style: TextStyle(
                                color: Colors.white,
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
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${entry.key} → ${entry.value}',
                                style: const TextStyle(
                                  color: Colors.white,
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
      return Column(
        children: [
          Text(
            question['question_text'] ?? 'Вопрос без текста',
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
          if (questionImage != null) questionImage,
          const SizedBox(height: 20),
          TextField(
            controller: answerController,
            textInputAction: TextInputAction.done,
            keyboardType: questionType == 'number' ? TextInputType.number : TextInputType.text,
            enableSuggestions: true,
            autocorrect: true,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: questionType == 'number' ? 'Введите число' : 'Ваш ответ',
              labelStyle: const TextStyle(color: Colors.white),
              enabledBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
              hintText: questionType == 'two_words' ? 'Введите два слова через пробел' : null,
              hintStyle: const TextStyle(color: Colors.white70),
            ),
            style: const TextStyle(color: Colors.white),
            cursorColor: Colors.white,
            inputFormatters: questionType == 'number' 
              ? [FilteringTextInputFormatter.digitsOnly]
              : null,
          ),
        ],
      );
    } else if (questionType == 'sequence') {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
            question['question_text'] ?? 'Вопрос без текста',
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
          if (questionImage != null) questionImage,
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
    } else if (question['options'] != null) {
      try {
        var options = json.decode(question['options'] as String);
        if (options is List && options.isNotEmpty) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                question['question_text'] ?? 'Вопрос без текста',
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
              if (questionImage != null) questionImage,
              const SizedBox(height: 20),
              ...options.map((option) => RadioListTile<String>(
                title: Text(
                  option.toString(),
                  style: const TextStyle(color: Colors.white),
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
          );
        }
      } catch (e) {
        debugPrint('Ошибка при разборе options: $e');
      }
      
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

        return Column(
          children: [
            Text(
            question['question_text'] ?? 'Вопрос без текста',
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
          if (questionImage != null) questionImage,
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
    } else if (questionType == 'multi_choice') {
      // Получаем текст вопроса, который содержит варианты ответов A, Б, В и т.д.
      final questionText = question['question_text'] as String? ?? 'Вопрос без текста';
      
      // Разделяем вопрос и варианты ответов (если они есть в тексте вопроса)
      List<String> questionParts = questionText.split('\n');
      String mainQuestion = questionParts[0];
      List<String> options = [];
      
      // Если в тексте вопроса были варианты, извлекаем их
      for (int i = 1; i < questionParts.length; i++) {
        final line = questionParts[i].trim();
        if (line.startsWith('А)') || line.startsWith('Б)') || 
            line.startsWith('В)') || line.startsWith('Г)') || 
            line.startsWith('Д)') || line.startsWith('Е)')) {
          options.add(line);
        }
      }
      
      // Если варианты ответов не найдены в тексте вопроса, создаем заглушки
      if (options.isEmpty) {
        options = ['А) Вариант А', 'Б) Вариант Б', 'В) Вариант В', 'Г) Вариант Г'];
      }
      
      // Получаем выбранные пользователем буквы
      List<String> selectedLetters = [];
      if (selectedAnswer != null && selectedAnswer!.isNotEmpty) {
        selectedLetters = selectedAnswer!.split('');
      }
      
      return Column(
        children: [
          Text(
            mainQuestion,
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
          if (questionImage != null) questionImage,
          const SizedBox(height: 10),
          // Отображаем варианты ответов из текста вопроса
          ...options.map((option) {
            // Получаем букву варианта ответа (А, Б, В, Г, Д, Е)
            String letter = option.substring(0, 1);
            bool isSelected = selectedLetters.contains(letter);
            
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  // Кнопка выбора
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          if (isSelected) {
                            // Если буква уже выбрана, убираем ее
                            selectedLetters.remove(letter);
                          } else {
                            // Иначе добавляем букву
                            selectedLetters.add(letter);
                          }
                          // Обновляем selectedAnswer
                          selectedAnswer = selectedLetters.join('');
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
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Текст варианта ответа
                  Expanded(
                    child: Text(
                      option,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          
          // Отображаем выбранные буквы
          if (selectedLetters.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Выбранные варианты: ${selectedLetters.join(', ')}',
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
      return Column(
        children: [
          Text(
            question['question_text'] ?? 'Неизвестный тип вопроса',
            style: const TextStyle(
              fontSize: 20,
              color: Colors.white,
            ),
          ),
          if (questionImage != null) questionImage,
          const SizedBox(height: 20),
          const Text(
            'Неизвестный формат вопроса',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      );
    }

    return const Center(
      child: Text(
        'Неподдерживаемый тип вопроса',
        style: TextStyle(color: Colors.white),
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
    int minutes = _timeLeft ~/ 60;
    int seconds = _timeLeft % 60;
    String timeString = '${minutes.toString().padLeft(2, '0')}:${seconds
        .toString().padLeft(2, '0')}';

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

class MatchingDragDrop extends StatefulWidget {
  final List<Map<String, dynamic>> leftItems;
  final List<Map<String, dynamic>> rightItems;
  final Function(Map<String, String>) onMatchesChanged;
  final Map<String, String> currentMatches;

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
  @override
  Widget build(BuildContext context) {
    // Создаем более компактную структуру
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Левая колонка (элементы, которые можно перетаскивать)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: ListView.builder(
              itemCount: widget.leftItems.length,
              shrinkWrap: true,
              itemBuilder: (context, index) {
                final item = widget.leftItems[index];
                final itemIndex = item['item_index'] as String? ?? '';
                final itemText = item['item_text'] as String? ?? '';
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8), // Увеличиваем отступ
                  child: _buildDraggableItem(
                    itemIndex,
                    itemText,
                    const Color(0xFF245020),
                    isLeft: true,
                  ),
                );
              },
            ),
          ),
        ),
        
        const SizedBox(width: 6),
        
        // Правая колонка (целевые элементы)
        Expanded(
          child: ListView.builder(
            itemCount: widget.rightItems.length,
            shrinkWrap: true,
            itemBuilder: (context, index) {
              final item = widget.rightItems[index];
              final itemIndex = item['item_index'] as String? ?? '';
              final itemText = item['item_text'] as String? ?? '';
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 8), // Увеличиваем отступ
                child: _buildDropTarget(
                  itemIndex,
                  itemText,
                  const Color(0xFF3d82b4),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDraggableItem(String itemIndex, String itemText, Color color, {required bool isLeft}) {
    // Элемент, который можно перетаскивать
    return LayoutBuilder(
      builder: (context, constraints) {
        return Draggable<String>(
          data: itemIndex,
          feedback: Material(
            color: Colors.transparent,
            child: Container(
              width: constraints.maxWidth,
              padding: const EdgeInsets.all(10), // Увеличиваем отступы
              decoration: BoxDecoration(
                color: color.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8), // Увеличиваем отступы
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      itemIndex,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16, // Увеличиваем размер шрифта
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      itemText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.5,
            child: _buildItemCard(itemIndex, itemText, color),
          ),
          child: _buildItemCard(itemIndex, itemText, color),
        );
      },
    );
  }

  Widget _buildDropTarget(String itemIndex, String itemText, Color color) {
    // Целевой элемент, на который можно перетащить
    return DragTarget<String>(
      builder: (context, candidateData, rejectedData) {
        final hasMatch = widget.currentMatches.values.contains(itemIndex);
        
        return _buildItemCard(
          itemIndex, 
          itemText, 
          hasMatch ? color.withOpacity(0.7) : color,
          isTarget: true,
          isMatched: hasMatch,
        );
      },
      onAccept: (String leftItemIndex) {
        // Удаляем предыдущее соответствие для этого leftItemIndex, если оно есть
        final newMatches = Map<String, String>.from(widget.currentMatches);
        newMatches[leftItemIndex] = itemIndex;
        
        widget.onMatchesChanged(newMatches);
      },
    );
  }

  Widget _buildItemCard(String itemIndex, String itemText, Color color, {bool isTarget = false, bool isMatched = false}) {
    return Container(
      padding: const EdgeInsets.all(8), // Увеличиваем отступы
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8), // Увеличиваем скругление
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
        border: isMatched ? Border.all(color: Colors.yellow, width: 2) : null, // Изменяем цвет рамки
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6), // Увеличиваем отступы
            decoration: BoxDecoration(
              color: color.withOpacity(0.7),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              itemIndex,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14, // Увеличиваем размер шрифта
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              itemText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13, // Увеличиваем размер шрифта
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
