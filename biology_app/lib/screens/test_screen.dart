import 'package:flutter/material.dart';
import '../database.dart';
import 'results_screen.dart';

class TestScreen extends StatefulWidget {
  final int topicId;
  final String topicTitle;

  const TestScreen({
    super.key,
    required this.topicId,
    required this.topicTitle,
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

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final loadedQuestions = await DBProvider.db.getQuestionsByTopicId(widget.topicId);
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

  Widget _buildQuestion(Map<String, dynamic> question) {
    if (question['is_open_ended'] == 1) {
      return Column(
        children: [
          Text(
            question['question_text'],
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: answerController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Ваш ответ',
            ),
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
              style: const TextStyle(fontSize: 18),
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
                style: const TextStyle(fontSize: 16),
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
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 20),
            ...answers.map((answer) => RadioListTile<String>(
                  title: Text(answer),
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
        ),
        child: Text(
          letter,
          style: const TextStyle(fontSize: 22),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.topicTitle),
      ),
      body: questions.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                LinearProgressIndicator(
                  value: (currentQuestionIndex + 1) / questions.length,
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                  minHeight: 10,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Вопрос ${currentQuestionIndex + 1}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'из ${questions.length}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
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
                            _saveAnswer();
                            if (currentQuestionIndex < questions.length - 1) {
                              setState(() {
                                currentQuestionIndex++;
                                selectedAnswer = null;
                                answerController.clear();
                                sequenceAnswer = '';
                              });
                            } else {
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
                          },
                          child: Text(
                            currentQuestionIndex < questions.length - 1
                                ? 'Следующий вопрос'
                                : 'Проверить результаты',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
} 