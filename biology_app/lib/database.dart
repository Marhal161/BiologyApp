import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
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
    
    // Проверяем, существует ли файл базы данных
    bool exists = await File(path).exists();
    
    if (!exists) {
      // Если файл не существует, создаем базу данных
      return await openDatabase(
        path, 
        version: 3,
        onCreate: (Database db, int version) async {
          await db.execute("""
            CREATE TABLE Chapters (
              id INTEGER PRIMARY KEY,
              image_path TEXT,
              title TEXT,
              order_number INTEGER
            )
          """);
          
          await db.execute("""
            CREATE TABLE Topics (
              id INTEGER PRIMARY KEY,
              chapter_id INTEGER,
              title TEXT,
              image_path TEXT,
              order_number INTEGER,
              FOREIGN KEY (chapter_id) REFERENCES Chapters (id)
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
              is_open_ended INTEGER,
              options TEXT,
              FOREIGN KEY (topic_id) REFERENCES Topics (id)
            )
          """);
        },
        onUpgrade: (Database db, int oldVersion, int newVersion) async {
          if (oldVersion < 3) {
            await db.execute("""
              CREATE TABLE Chapters (
                id INTEGER PRIMARY KEY,
                title TEXT,
                order_number INTEGER,
                image_path TEXT
              )
            """);
            await db.execute("ALTER TABLE Topics ADD COLUMN chapter_id INTEGER REFERENCES Chapters (id)");
            await db.execute("ALTER TABLE Topics ADD COLUMN order_number INTEGER");
          }
        },
      );
    } else {
      // Если файл существует, просто открываем его
      return await openDatabase(path);
    }
  }

  Future<List<Map<String, dynamic>>> getQuestionsByTopicId(int topicId) async {
    final db = await database;
    return await db.query(
      'Questions',
      where: 'topic_id = ?',
      whereArgs: [topicId],
    );
  }

  Future<void> insertTopic(String title, String imagePath, {int? chapterId, int? orderNumber}) async {
    final db = await database;
    await db.insert(
      'Topics',
      {
        'title': title,
        'image_path': imagePath,
        'chapter_id': chapterId,
        'order_number': orderNumber,
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
    await db.delete('Chapters');
    await db.delete('Topics');
    await db.delete('Questions');
  }

  Future<void> importFromDatabaseFile() async {
    try {
      // Получаем путь к директории приложения
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      String dbPath = join(documentsDirectory.path, "BiologyDB.db");
      
      // Закрываем текущее соединение с базой данных, если оно открыто
      if (_database != null) {
        await _database!.close();
        _database = null;
      }
      
      // Удаляем существующий файл базы данных, если он есть
      if (await File(dbPath).exists()) {
        await File(dbPath).delete();
      }
      
      // Копируем файл базы данных из assets
      ByteData data = await rootBundle.load("assets/database.db");
      List<int> bytes = data.buffer.asUint8List();
      await File(dbPath).writeAsBytes(bytes);
      
      // Открываем скопированную базу данных
      _database = await openDatabase(dbPath);
      
      print('База данных успешно импортирована из файла');
    } catch (e) {
      print('Ошибка при импорте базы данных из файла: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getTopics() async {
    final db = await database;
    final topics = await db.query('Topics');
    print('Получены темы: $topics');
    return topics;
  }

  Future<void> insertChapter(String title, int orderNumber, String imagePath) async {
    final db = await database;
    await db.insert(
      'Chapters',
      {
        'title': title,
        'order_number': orderNumber,
        'image_path': imagePath,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getChapters() async {
    final db = await database;
    return await db.query(
      'Chapters',
      orderBy: 'order_number ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getTopicsByChapter(int chapterId) async {
    final db = await database;
    return await db.query(
      'Topics',
      where: 'chapter_id = ?',
      whereArgs: [chapterId],
      orderBy: 'order_number ASC',
    );
  }
}