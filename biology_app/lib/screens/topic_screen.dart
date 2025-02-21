import 'package:flutter/material.dart';
import 'dart:ui'; // For the BackdropFilter
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
        title: Text(
          topicTitle,
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
                        return _SettingsMenu();
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

class _SettingsMenu extends StatefulWidget {
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
                title: Text('Таймер'),
                value: isTimerChecked,
                onChanged: (bool? value) {
                  setState(() {
                    isTimerChecked = value ?? false;
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
