import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart' show rootBundle;

class DBProvider {
  DBProvider._();
  static final DBProvider db = DBProvider._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await initDB();
    return _database!;
  }

  Future<Database> initDB() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, "BiologyDB.db");
    return await openDatabase(
      path, 
      version: 2,
      onOpen: (db) {},
      onCreate: (Database db, int version) async {
        await db.execute("""
          CREATE TABLE Topics (
            id INTEGER PRIMARY KEY,
            title TEXT,
            image_path TEXT
          )
        """);
        
        await db.execute("""
          CREATE TABLE Questions (
            id INTEGER PRIMARY KEY,
            topic_id INTEGER,
            question_text TEXT,
            correct_answer TEXT,
            wrong_answer1 TEXT,
            wrong_answer2 TEXT,
            wrong_answer3 TEXT,
            wrong_answer4 TEXT,
            is_open_ended BIT,
            options TEXT,
            FOREIGN KEY (topic_id) REFERENCES Topics (id)
          )
        """);
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        if (oldVersion < 2) {
          await db.execute("ALTER TABLE Questions ADD COLUMN options TEXT");
        }
      },
    );
  }

  Future<List<Map<String, dynamic>>> getQuestionsByTopicId(int topicId) async {
    final db = await database;
    return await db.query(
      'Questions',
      where: 'topic_id = ?',
      whereArgs: [topicId],
    );
  }

  Future<void> insertTopic(String title, String imagePath) async {
    final db = await database;
    await db.insert(
      'Topics',
      {
        'title': title,
        'image_path': imagePath,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertQuestion(int topicId, String questionText, String correctAnswer, List<String> wrongAnswers, bool isOpenEnded, {List<String>? options}) async {
    final db = await database;
    await db.insert(
      'Questions',
      {
        'topic_id': topicId,
        'question_text': questionText,
        'correct_answer': correctAnswer,
        'wrong_answer1': wrongAnswers[0],
        'wrong_answer2': wrongAnswers[1],
        'wrong_answer3': wrongAnswers[2],
        'wrong_answer4': wrongAnswers[3],
        'is_open_ended': isOpenEnded ? 1 : 0,
        'options': options != null ? json.encode(options) : null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearDatabase() async {
    final db = await database;
    await db.delete('Topics');
    await db.delete('Questions');
  }

  Future<void> importFromCSV() async {
    await clearDatabase();
    
    try {
      // Проверяем наличие файла
      bool exists = await rootBundle.load('assets/data/topics.csv').then((_) => true).catchError((_) => false);
      print('Файл topics.csv существует: $exists');

      if (!exists) {
        print('Файл topics.csv не найден!');
        return;
      }

      // Импорт тем
      final topicsString = await rootBundle.loadString('assets/data/topics.csv');
      print('Содержимое topics.csv: $topicsString');
      
      if (topicsString.isEmpty) {
        print('Файл topics.csv пуст!');
        return;
      }

      List<List<dynamic>> topics = const CsvToListConverter().convert(topicsString);
      print('Конвертированные темы: $topics');
      
      if (topics.isEmpty) {
        print('Нет тем для импорта!');
        return;
      }

      // Пропускаем заголовок
      for (var topic in topics.skip(1)) {
        print('Вставка темы: $topic');
        await insertTopic(
          topic[1], // title
          topic[2], // image_path
        );
      }

      // Проверяем результат
      final db = await database;
      final allTopics = await db.query('Topics');
      print('Темы в базе данных: $allTopics');

    } catch (e, stackTrace) {
      print('Ошибка при импорте: $e');
      print('Stack trace: $stackTrace');
    }
    
    // Импорт вопросов
    final questionsString = await rootBundle.loadString('assets/data/questions.csv');
    List<List<dynamic>> questions = const CsvToListConverter().convert(questionsString);
    
    // Пропускаем заголовок
    for (var question in questions.skip(1)) {
      await insertQuestion(
        int.parse(question[1]), // topic_id
        question[2], // question_text
        question[3], // correct_answer
        [
          question[4], // wrong_answer1
          question[5], // wrong_answer2
          question[6], // wrong_answer3
          question[7], // wrong_answer4
        ],
        question[8] == '1', // is_open_ended
      );
    }
  }

  Future<void> importFromJSON() async {
    final jsonString = await rootBundle.loadString('assets/data/database.json');
    final data = json.decode(jsonString);

    // Импорт тем
    for (var topic in data['topics']) {
      await insertTopic(
        topic['title'],
        topic['image_path'],
      );
    }

    // Импорт вопросов
    for (var question in data['questions']) {
      await insertQuestion(
        question['topic_id'],
        question['question_text'],
        question['correct_answer'],
        List<String>.from(question['wrong_answers']),
        question['is_open_ended'],
      );
    }
  }

  Future<void> copyDatabase() async {
    // Путь к базе данных в приложении
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, "BiologyDB.db");

    // Проверяем, существует ли база данных
    if (FileSystemEntity.typeSync(path) == FileSystemEntityType.notFound) {
      // Копируем базу данных из assets
      ByteData data = await rootBundle.load("assets/database/biology.db");
      List<int> bytes = data.buffer.asUint8List();
      await File(path).writeAsBytes(bytes);
    }
  }

  Future<List<Map<String, dynamic>>> getTopics() async {
    final db = await database;
    final topics = await db.query('Topics');
    print('Получены темы: $topics');
    return topics;
  }

  Future<void> importTopicFromJSON(int topicNumber) async {
    try {
      final jsonString = await rootBundle.loadString('assets/data/topic$topicNumber.json');
      final data = json.decode(jsonString);
      
      // Импорт темы
      final topic = data['topic'];
      await insertTopic(
        topic['title'],
        topic['image_path'],
      );
      
      // Импорт вопросов
      final questions = data['questions'] as List;
      for (var question in questions) {
        await insertQuestion(
          topic['id'],
          question['question_text'],
          question['correct_answer'],
          List<String>.from(question['wrong_answers']),
          question['is_open_ended'],
          options: question['options'] != null ? List<String>.from(question['options']) : null,
        );
      }
      
      print('Тема $topicNumber импортирована успешно');
    } catch (e) {
      print('Ошибка при импорте темы $topicNumber: $e');
    }
  }
}