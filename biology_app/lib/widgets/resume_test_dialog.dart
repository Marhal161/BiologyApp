import 'package:flutter/material.dart';
import '../services/test_progress_service.dart';

class ResumeTestDialog extends StatelessWidget {
  final String topicTitle;
  final TestState savedState;
  final VoidCallback onResumeTest;
  final VoidCallback onStartNew;

  const ResumeTestDialog({
    Key? key,
    required this.topicTitle,
    required this.savedState,
    required this.onResumeTest,
    required this.onStartNew,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final progress = ((savedState.currentQuestionIndex + 1) / savedState.userAnswers.length * 100).round();
    final timeAgo = _getTimeAgo(savedState.savedAt);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.quiz, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Продолжить тест?',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            topicTitle,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.blue.shade600),
                    const SizedBox(width: 4),
                    Text(
                      'Сохранено: $timeAgo',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.trending_up, size: 16, color: Colors.green.shade600),
                    const SizedBox(width: 4),
                    Text(
                      'Прогресс: ${savedState.currentQuestionIndex + 1} из ${savedState.userAnswers.length} ($progress%)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress / 100,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Вы можете продолжить с вопроса ${savedState.currentQuestionIndex + 1} или начать тест заново.',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onStartNew();
          },
          style: TextButton.styleFrom(
            foregroundColor: Colors.orange.shade600,
          ),
          child: const Text('Начать заново'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onResumeTest();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Продолжить'),
        ),
      ],
    );
  }

  String _getTimeAgo(DateTime savedAt) {
    final now = DateTime.now();
    final difference = now.difference(savedAt);

    if (difference.inMinutes < 1) {
      return 'только что';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} мин назад';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ч назад';
    } else {
      return '${difference.inDays} дн назад';
    }
  }

  static Future<void> show({
    required BuildContext context,
    required String topicTitle,
    required TestState savedState,
    required VoidCallback onResumeTest,
    required VoidCallback onStartNew,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return ResumeTestDialog(
          topicTitle: topicTitle,
          savedState: savedState,
          onResumeTest: onResumeTest,
          onStartNew: onStartNew,
        );
      },
    );
  }
} 