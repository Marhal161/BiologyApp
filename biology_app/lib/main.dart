import 'package:flutter/material.dart';
//import 'screens/categories_screen.dart';
import 'database.dart';
import 'screens/chapters_screen.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await DBProvider.db.initDB();
    await DBProvider.db.clearDatabase();
    print('База данных очищена');
    
    // Импортируем темы
    await DBProvider.db.importTopicFromJSON(1);
    // Добавьте импорт других тем при необходимости
    // await DBProvider.db.importTopicFromJSON(2);
    // await DBProvider.db.importTopicFromJSON(3);
    
    runApp(const MainApp());
  } catch (e) {
    print('Ошибка при запуске: $e');
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const StartScreen(),
    );
  }
}

class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Добро пожаловать',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Мелкий текст здесь',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ChaptersScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
              ),
              child: const Text(
                'Начать',
                style: TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
