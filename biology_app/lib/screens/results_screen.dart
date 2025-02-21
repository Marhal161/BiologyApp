import 'package:flutter/material.dart';
import 'categories_screen.dart'; // Импортируем CategoriesScreen

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
      if (userAnswers[i]?.toUpperCase() ==
          questions[i]['correct_answer'].toString().toUpperCase()) {
        correctAnswers++;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Результаты теста',
          style: TextStyle(
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Тема: $topicTitle',
                style: const TextStyle(
                  fontSize: 20,
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
              const SizedBox(height: 20),
              Text(
                'Правильных ответов: $correctAnswers из ${questions.length}',
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
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Вопрос:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(question['question_text']),
                            const SizedBox(height: 8),
                            Text(
                              'Ваш ответ: ${userAnswer ?? "Нет ответа"}',
                              style: TextStyle(
                                color: isCorrect ? Colors.green : Colors.red,
                              ),
                            ),
                            if (!isCorrect)
                              Text(
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
                    // Переход на экран категорий
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CategoriesScreen(
                          chapterId: 1, // Укажите нужный ID главы
                          chapterTitle: 'Название главы', // Укажите нужное название
                          chapterImage:
                          'assets/images/bioChap1.jpeg', // Укажите нужное изображение
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF2F642D), // Цвет кнопки
                    foregroundColor: Colors.white, // Цвет текста кнопки
                    elevation: 4, // Установка elevation на 4
                    shadowColor: Colors.black, // Цвет тени
                  ),
                  child: const Text(
                    'Перейти к категориям',
                    style: TextStyle(
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
}
