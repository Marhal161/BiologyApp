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

                // Переход на следующий экран с анимацией
                Navigator.push(
                  context,
                  _createRoute(),
                );
              },
              child: const Text('Проверить ответ'),
            ),
          ],
        ),
      ),
    );
  }

  Route _createRoute() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => const NextScreen(),
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
}

class NextScreen extends StatelessWidget {
  const NextScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Следующий экран'),
      ),
      body: const Center(
        child: Text('Вы перешли на следующий экран!'),
      ),
    );
  }
}
