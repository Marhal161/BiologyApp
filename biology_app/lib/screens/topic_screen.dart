import 'package:flutter/material.dart';
import 'dart:ui'; // For the BackdropFilter
import 'test_screen.dart';
import '../services/test_progress_service.dart';

class TopicScreen extends StatefulWidget {
  final String topicTitle;
  final int topicId;
  final String chapterImage;

  const TopicScreen({
    super.key,
    required this.topicTitle,
    required this.topicId,
    required this.chapterImage,
  });

  @override
  State<TopicScreen> createState() => _TopicScreenState();
}

class _TopicScreenState extends State<TopicScreen> {
  bool isTimerEnabled = false;
  int timePerQuestion = 30;
  double? testScore;
  bool isTestCompleted = false;

  @override
  void initState() {
    super.initState();
    _loadTestProgress();
  }

  Future<void> _loadTestProgress() async {
    final completed = await TestProgressService.isTestCompleted(widget.topicId);
    final score = await TestProgressService.getTestScore(widget.topicId);

    setState(() {
      isTestCompleted = completed;
      testScore = score;
    });
  }

  Route _createRoute(Widget screen) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => screen,
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

  void _handleTimerCheckedChanged(bool value) {
    setState(() {
      isTimerEnabled = value;
    });
  }

  void _showTimePickerDialog() {
    bool isSnackBarVisible = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2F642D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text(
            'Установите время',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Укажите время на ответ (в секундах, максимум 300 секунд):',
                style: TextStyle(color: Colors.white),
              ),
              TextField(
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white70),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty) {
                    int newTime = int.tryParse(value) ?? 0;
                    if (newTime > 300) {
                      if (!isSnackBarVisible) {
                        isSnackBarVisible = true;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Максимальное время - 300 секунд (5 минут)'),
                            backgroundColor: Colors.red,
                            duration: Duration(seconds: 2),
                          ),
                        ).closed.then((_) => isSnackBarVisible = false);
                      }
                    } else if (newTime < 1) {
                      if (!isSnackBarVisible) {
                        isSnackBarVisible = true;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Минимальное время - 1 секунда'),
                            backgroundColor: Colors.red,
                            duration: Duration(seconds: 2),
                          ),
                        ).closed.then((_) => isSnackBarVisible = false);
                      }
                    } else {
                      setState(() {
                        timePerQuestion = newTime;
                      });
                    }
                  }
                },
                controller: TextEditingController(text: timePerQuestion.toString()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () {
                if (timePerQuestion <= 300 && timePerQuestion >= 1) {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    _createRoute(TestScreen(
                      topicId: widget.topicId,
                      topicTitle: widget.topicTitle,
                      isTimerEnabled: true,
                      timePerQuestion: timePerQuestion,
                    )),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF2F642D),
              ),
              child: const Text('Начать', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.topicTitle,
          style: const TextStyle(
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
        iconTheme: const IconThemeData(
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
      body: Stack(
        children: [
          // Фоновое изображение
          Positioned.fill(
            child: Image.asset(
              widget.chapterImage,
              fit: BoxFit.cover,
            ),
          ),
          // Размытие фона
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Container(
              color: Colors.black.withOpacity(0.5),
            ),
          ),
          // Основной контент
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Информация о прохождении теста
                if (isTestCompleted)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: testScore! >= 90
                          ? Colors.green.withOpacity(0.7)
                          : Colors.orange.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          testScore! >= 90 ? Icons.check_circle : Icons.info,
                          color: Colors.white,
                          size: 40,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Тест пройден с результатом: ${testScore!.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          testScore! >= 90
                              ? 'Отличный результат!'
                              : 'Вы можете пройти тест еще раз для улучшения результата.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (BuildContext context) {
                          return _SettingsMenu(
                            onTimerCheckedChanged: _handleTimerCheckedChanged,
                            isTimerEnabled: isTimerEnabled,
                          );
                        },
                      );
                    },
                    iconSize: 40,
                    color: Colors.white,
                    splashColor: Colors.white.withOpacity(0.3),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    if (isTimerEnabled) {
                      _showTimePickerDialog();
                    } else {
                      Navigator.pushReplacement(
                        context,
                        _createRoute(TestScreen(
                          topicId: widget.topicId,
                          topicTitle: widget.topicTitle,
                          isTimerEnabled: false,
                          timePerQuestion: 0,
                        )),
                      ).then((_) {
                        // Обновляем информацию о прохождении теста при возвращении
                        _loadTestProgress();
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2F642D),
                    padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                    shadowColor: Colors.black,
                    elevation: 4,
                  ),
                  child: Text(
                    isTestCompleted ? 'Пройти тест снова' : 'Начать тестирование',
                    style: const TextStyle(
                      fontSize: 24,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          offset: Offset(0, 2),
                          blurRadius: 10,
                        ),
                      ],
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsMenu extends StatelessWidget {
  final Function(bool) onTimerCheckedChanged;
  final bool isTimerEnabled;

  const _SettingsMenu({
    required this.onTimerCheckedChanged,
    required this.isTimerEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Container(
              color: Colors.black.withOpacity(0),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          height: MediaQuery.of(context).size.height * 0.4,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                'Меню настроек',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              CheckboxListTile(
                title: const Text('Таймер'),
                value: isTimerEnabled,
                onChanged: (bool? value) {
                  onTimerCheckedChanged(value ?? false);
                  Navigator.pop(context);
                },
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: Colors.green,
                checkColor: Colors.white,
              ),
            ],
          ),
        ),
      ],
    );
  }
}