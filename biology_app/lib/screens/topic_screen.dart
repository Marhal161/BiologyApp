import 'package:flutter/material.dart';
import 'test_screen.dart';

class TopicScreen extends StatelessWidget {
  final String topicTitle;
  final int topicId;

  const TopicScreen({
    super.key,
    required this.topicTitle,
    required this.topicId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(topicTitle, style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xFF2F642D),
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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          TestScreen(
                            topicId: topicId,
                            topicTitle: topicTitle,
                          ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2F642D),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 50, vertical: 15),
                ),
                child: const Text(
                  'Начать тестирование',
                  style: TextStyle(fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}