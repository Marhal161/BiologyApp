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
  bool isTimerChecked = false;
  int questionTimeInSeconds = 30;

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
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: Icon(Icons.settings),
                  onPressed: () {
                    // Show the sliding menu from the bottom
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent, // Make background transparent for blur effect
                      builder: (BuildContext context) {
                        return _SettingsMenu(onTimerCheckedChanged: (bool value) {
                          setState(() {
                            isTimerChecked = value;
                          });
                        });
                      },
                    );
                  },
                  iconSize: 40, // Icon size
                  color: Colors.white,
                  splashColor: Colors.white.withOpacity(0.3),
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (isTimerChecked) {
                    _showTimePickerDialog(context);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TestScreen(
                          topicId: widget.topicId,
                          topicTitle: widget.topicTitle,
                          timePerQuestion: 0,
                          isTimerEnabled: false,
                        ),
                      ),
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

  void _showTimePickerDialog(BuildContext context) {
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
                  color: Colors.black26,
                  offset: Offset(0, 2),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Укажите время на ответ (в секундах):',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
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
                    questionTimeInSeconds = int.parse(value);
                  }
                },
                controller: TextEditingController(text: questionTimeInSeconds.toString()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'Отмена',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TestScreen(
                      topicId: widget.topicId,
                      topicTitle: widget.topicTitle,
                      timePerQuestion: questionTimeInSeconds,
                      isTimerEnabled: true,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF2F642D),
              ),
              child: const Text(
                'Начать',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SettingsMenu extends StatefulWidget {
  final Function(bool) onTimerCheckedChanged;
  
  const _SettingsMenu({
    required this.onTimerCheckedChanged,
  });

  @override
  _SettingsMenuState createState() => _SettingsMenuState();
}

class _SettingsMenuState extends State<_SettingsMenu> {
  // Manage checkbox state locally in the settings menu
  bool isTimerChecked = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // BackdropFilter to apply the blur effect on the background
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Container(
              color: Colors.black.withOpacity(0),
            ),
          ),
        ),
        // Sliding menu content
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          // Add a fixed height to make the menu higher
          height: MediaQuery.of(context).size.height * 0.4, // Adjust this value to make the menu higher or lower
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('Меню настроек', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              CheckboxListTile(
                title: const Text('Таймер'),
                value: isTimerChecked,
                onChanged: (bool? value) {
                  setState(() {
                    isTimerChecked = value ?? false;
                    widget.onTimerCheckedChanged(isTimerChecked);
                  });
                },
                controlAffinity: ListTileControlAffinity.leading, // Checkbox on the left side
                activeColor: Colors.green, // Change active (checked) color
                checkColor: Colors.white, // Change check mark color
              ),
            ],
          ),
        ),
      ],
    );
  }
}
