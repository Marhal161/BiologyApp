import 'package:flutter/material.dart';

class ResultsScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    int correctAnswers = 0;
    
    // Подсчет правильных ответов
    for (int i = 0; i < questions.length; i++) {
      if (userAnswers[i]?.toUpperCase() == questions[i]['correct_answer'].toString().toUpperCase()) {
        correctAnswers++;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Результаты теста'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Тема: $topicTitle',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Text(
              'Правильных ответов: $correctAnswers из ${questions.length}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: questions.length,
                itemBuilder: (context, index) {
                  final question = questions[index];
                  final userAnswer = userAnswers[index];
                  final isCorrect = userAnswer?.toUpperCase() == 
                      question['correct_answer'].toString().toUpperCase();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Вопрос ${index + 1}:',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(question['question_text']),
                          const SizedBox(height: 8),
                          Text(
                            'Ваш ответ: ${userAnswer ?? "Нет ответа"}',
                            style: TextStyle(
                              color: isCorrect ? Colors.green : Colors.red,
                            ),
                          ),
                          if (!isCorrect) Text(
                            'Правильный ответ: ${question['correct_answer']}',
                            style: const TextStyle(color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.popUntil(
                    context,
                    (route) => route.isFirst,
                  );
                },
                child: const Text('Завершить'),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 