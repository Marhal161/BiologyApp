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
        title: Text(topicTitle),
      ),  
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TestScreen(
                      topicId: topicId,
                      topicTitle: topicTitle,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
              ),
              child: const Text(
                'Начать тестирование',
                style: TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 