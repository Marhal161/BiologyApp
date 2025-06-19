import 'package:flutter/material.dart';
import 'dart:ui';
import 'test_screen.dart';
import '../services/test_progress_service.dart';
import 'package:google_fonts/google_fonts.dart';

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
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTestProgress();
  }

  Future<void> _loadTestProgress() async {
    try {
      final completed = await TestProgressService.isTestCompleted(widget.topicId);
      final score = await TestProgressService.getTestScore(widget.topicId);

      setState(() {
        isTestCompleted = completed;
        testScore = score;
        isLoading = false;
      });
    } catch (e) {
      print('Ошибка загрузки прогресса: $e');
      setState(() {
        isLoading = false;
      });
    }
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
          backgroundColor: const Color(0xFF42A5F5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Text(
            'Установите время',
            style: GoogleFonts.montserrat(
              textStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Укажите время на ответ (в секундах, максимум 300 секунд):',
                style: GoogleFonts.montserrat(
                  textStyle: const TextStyle(color: Colors.white),
                ),
              ),
              TextField(
                style: GoogleFonts.montserrat(
                  textStyle: const TextStyle(color: Colors.white),
                ),
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
                          SnackBar(
                            content: Text(
                              'Максимальное время - 300 секунд (5 минут)',
                              style: GoogleFonts.montserrat(),
                            ),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 2),
                          ),
                        ).closed.then((_) => isSnackBarVisible = false);
                      }
                    } else if (newTime < 1) {
                      if (!isSnackBarVisible) {
                        isSnackBarVisible = true;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Минимальное время - 1 секунда',
                              style: GoogleFonts.montserrat(),
                            ),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 2),
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
              child: Text(
                'Отмена',
                style: GoogleFonts.montserrat(
                  textStyle: const TextStyle(color: Colors.white70),
                ),
              ),
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
                foregroundColor: const Color(0xFF42A5F5),
              ),
              child: Text(
                'Начать',
                style: GoogleFonts.montserrat(
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: Image.asset("assets/images/backgroundfirstchapter.jpg").image,
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            // Кастомный заголовок вместо AppBar
            Padding(
              padding: const EdgeInsets.only(top: 40.0, left: 16.0, right: 16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                    color: Colors.black87,
                    iconSize: 30,
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        widget.topicTitle,
                        style: GoogleFonts.montserrat(
                          textStyle: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
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
                    color: Colors.black87,
                    iconSize: 30,
                  ),
                ],
              ),
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.black87))
                  : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isTestCompleted)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: testScore! >= 90
                              ? Colors.green.withOpacity(0.7)
                              : Colors.orange.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
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
                              style: GoogleFonts.montserrat(
                                textStyle: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              testScore! >= 90
                                  ? 'Отличный результат!'
                                  : 'Вы можете пройти тест еще раз для улучшения результата.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.montserrat(
                                textStyle: const TextStyle(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
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
                            _loadTestProgress();
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF42A5F5),
                        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                        shadowColor: Colors.black12,
                        elevation: 4,
                      ),
                      child: Text(
                        isTestCompleted ? 'Пройти тест снова' : 'Начать тестирование',
                        style: GoogleFonts.montserrat(
                          textStyle: const TextStyle(
                            fontSize: 24,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
    return Stack(
      children: [
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
            child: Container(
              color: Colors.black.withOpacity(0),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          height: MediaQuery.of(context).size.height * 0.4,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Меню настроек',
                style: GoogleFonts.montserrat(
                  textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w400),
                ),
              ),
              const SizedBox(height: 20),
              CheckboxListTile(
                title: Text(
                  'Таймер',
                  style: GoogleFonts.montserrat(),
                ),
                value: isTimerEnabled,
                onChanged: (bool? value) {
                  onTimerCheckedChanged(value ?? false);
                  Navigator.pop(context);
                },
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: const Color(0xFF42A5F5),
                checkColor: Colors.white,
              ),
            ],
          ),
        ),
      ],
    );
  }
}