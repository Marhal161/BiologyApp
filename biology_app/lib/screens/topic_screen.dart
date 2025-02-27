import 'package:flutter/material.dart';
import 'dart:ui'; // For the BackdropFilter
import 'test_screen.dart';

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

  void _handleTimerCheckedChanged(bool value) {
    setState(() {
      isTimerEnabled = value;
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
              fontSize: 22,
              shadows: [
                Shadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 10)
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
                      timePerQuestion = newTime;
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
                  Navigator.push(
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
                    Navigator.push(
                      context,
                      _createRoute(TestScreen(
                        topicId: widget.topicId,
                        topicTitle: widget.topicTitle,
                        isTimerEnabled: false,
                        timePerQuestion: 0,
                      )),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2F642D),
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  shadowColor: Colors.black,
                  elevation: 4,
                ),
                child: const Text(
                  'Начать тестирование',
                  style: TextStyle(
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

class _SettingsMenu extends StatelessWidget {
  final Function(bool) onTimerCheckedChanged;
  final bool isTimerEnabled;

  const _SettingsMenu({
    required this.onTimerCheckedChanged,
    required this.isTimerEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
