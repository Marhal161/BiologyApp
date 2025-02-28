import 'package:flutter/material.dart';
import 'dart:ui'; // For the BackdropFilter
import 'test_screen.dart';
import '../services/test_progress_service.dart';

class TopicScreen extends StatefulWidget {
  final String topicTitle;
  final int topicId;

  const TopicScreen({
    super.key,
    required this.topicTitle,
    required this.topicId,
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

  void _handleTimerCheckedChanged(bool value) {
    setState(() {
      isTimerEnabled = value;
    });
  }

  void _showTimePickerDialog() {
    // Переменная для отслеживания, показывается ли SnackBar
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
              fontSize: 22,
              shadows: [
                Shadow(
                    color: Colors.black26, offset: Offset(0, 2), blurRadius: 10)
              ],
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Укажите время на ответ (в секундах, максимум 300 секунд):',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 20),
              TextField(
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                  labelText: 'Время в секундах',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty) {
                    int newTime = int.parse(value);
                    if (newTime > 300) {
                      if (!isSnackBarVisible) {
                        isSnackBarVisible = true;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Максимальное время - 300 секунд (5 минут)'),
                            backgroundColor: Colors.red,
                            duration: Duration(seconds: 2),
                          ),
                        ).closed.then((_) {
                          isSnackBarVisible = false;
                        });
                      }
                    } else if (newTime < 1) {
                      if (!isSnackBarVisible) {
                        isSnackBarVisible = true;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Минимальное время - 1 секунда'),
                            backgroundColor: Colors.red,
                            duration: Duration(seconds: 2),
                          ),
                        ).closed.then((_) {
                          isSnackBarVisible = false;
                        });
                      }
                    } else {
                      timePerQuestion = newTime;
                    }
                  }
                },
                controller: TextEditingController(
                    text: timePerQuestion.toString()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                  'Отмена', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () {
                if (timePerQuestion <= 300 && timePerQuestion >= 1) {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TestScreen(
                        topicId: widget.topicId,
                        topicTitle: widget.topicTitle,
                        isTimerEnabled: true,
                        timePerQuestion: timePerQuestion,
                      ),
                    ),
                  );
                } else {
                  if (!isSnackBarVisible) {
                    isSnackBarVisible = true;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            timePerQuestion > 300
                                ? 'Максимальное время - 300 секунд (5 минут)'
                                : 'Минимальное время - 1 секунда'),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 2),
                      ),
                    ).closed.then((_) {
                      isSnackBarVisible = false;
                    });
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF2F642D),
              ),
              child: const Text(
                  'Начать', style: TextStyle(fontWeight: FontWeight.bold)),
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
        backgroundColor: Color(0xFF2F642D),
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
              // Перемещаем кнопку настроек в начало Column
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: Icon(Icons.settings),
                  onPressed: () {
                    // Show the sliding menu from the bottom
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      // Make background transparent for blur effect
                      builder: (BuildContext context) {
                        return _SettingsMenu(
                          onTimerCheckedChanged: _handleTimerCheckedChanged,
                          isTimerEnabled: isTimerEnabled,
                        );
                      },
                    );
                  },
                  iconSize: 40,
                  // Icon size
                  color: Colors.white,
                  splashColor: Colors.white.withOpacity(0.3),
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (isTimerEnabled) {
                    _showTimePickerDialog();
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TestScreen(
                          topicId: widget.topicId,
                          topicTitle: widget.topicTitle,
                          isTimerEnabled: false,
                          timePerQuestion: 0,
                        ),
                      ),
                    ).then((_) {
                      // Обновляем информацию о прохождении теста при возвращении
                      _loadTestProgress();
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2F642D),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 50, vertical: 15),
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
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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

class _SettingsMenu extends StatefulWidget {
  final Function(bool) onTimerCheckedChanged;
  final bool isTimerEnabled;

  const _SettingsMenu({
    required this.onTimerCheckedChanged,
    required this.isTimerEnabled,
  });

  @override
  State<_SettingsMenu> createState() => _SettingsMenuState();
}

class _SettingsMenuState extends State<_SettingsMenu> {
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
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
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
                value: widget.isTimerEnabled,
                onChanged: (bool? value) {
                  widget.onTimerCheckedChanged(value ?? false);
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