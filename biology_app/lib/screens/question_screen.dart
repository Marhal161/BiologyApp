import 'package:flutter/material.dart';

class QuestionScreen extends StatelessWidget {
  final String questionText;
  final bool isOpenEnded;

  const QuestionScreen({
    super.key,
    required this.questionText,
    required this.isOpenEnded,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Вопрос'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              questionText,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 20),
            if (isOpenEnded)
              TextField(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Ваш ответ',
                ),
              )
            else
              // Здесь можно добавить логику для отображения вариантов ответов
              Container(), // Замените на виджет с вариантами ответов
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Логика для проверки ответа
              },
              child: const Text('Проверить ответ'),
            ),
          ],
        ),
      ),
    );
  }
} 