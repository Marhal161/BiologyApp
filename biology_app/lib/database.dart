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
        version: 6,
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
              topic_id INTEGER NOT NULL,
              part TEXT NOT NULL,
              question_text TEXT NOT NULL,
              question_type TEXT NOT NULL,
              correct_answer TEXT,
              max_words INTEGER DEFAULT 1,
              image_path TEXT,
              FOREIGN KEY (topic_id) REFERENCES Topics (id)
            )
          """);

          await db.execute("""
            CREATE TABLE MatchingOptions (
              id INTEGER PRIMARY KEY,
              question_id INTEGER NOT NULL,
              item_text TEXT NOT NULL,
              item_group TEXT NOT NULL,
              item_index TEXT NOT NULL,
              FOREIGN KEY (question_id) REFERENCES Questions (id)
            )
          """);

          await db.execute("""
            CREATE TABLE MatchingAnswers (
              id INTEGER PRIMARY KEY,
              question_id INTEGER NOT NULL,
              left_item_index TEXT NOT NULL,
              right_item_index TEXT NOT NULL,
              FOREIGN KEY (question_id) REFERENCES Questions (id)
            )
          """);
        },
        onUpgrade: (Database db, int oldVersion, int newVersion) async {
          if (oldVersion < 6) {
            // Добавляем новое поле в существующую таблицу
            await db.execute('ALTER TABLE Questions ADD COLUMN image_path TEXT');
          }
          if (oldVersion < 5) {
            // Сохраняем старые данные если нужно
            final oldQuestions = await db.query('Questions');
            
            // Удаляем старые таблицы
            await db.execute('DROP TABLE IF EXISTS Questions');
            await db.execute('DROP TABLE IF EXISTS MatchingOptions');
            await db.execute('DROP TABLE IF EXISTS MatchingAnswers');
            
            // Создаем новые таблицы
            await db.execute("""
              CREATE TABLE Questions (
                id INTEGER PRIMARY KEY,
                topic_id INTEGER NOT NULL,
                part TEXT NOT NULL,
                question_text TEXT NOT NULL,
                question_type TEXT NOT NULL,
                correct_answer TEXT,
                max_words INTEGER DEFAULT 1,
                image_path TEXT,
                FOREIGN KEY (topic_id) REFERENCES Topics (id) ON DELETE CASCADE
              )
            """);

            await db.execute("""
              CREATE TABLE MatchingOptions (
                id INTEGER PRIMARY KEY,
                question_id INTEGER NOT NULL,
                item_text TEXT NOT NULL,
                item_group TEXT NOT NULL,
                item_index TEXT NOT NULL,
                FOREIGN KEY (question_id) REFERENCES Questions (id) ON DELETE CASCADE
              )
            """);

            await db.execute("""
              CREATE TABLE MatchingAnswers (
                id INTEGER PRIMARY KEY,
                question_id INTEGER NOT NULL,
                left_item_index TEXT NOT NULL,
                right_item_index TEXT NOT NULL,
                FOREIGN KEY (question_id) REFERENCES Questions (id) ON DELETE CASCADE
              )
            """);

            // Создаем индексы
            await db.execute('CREATE INDEX idx_questions_topic_part ON Questions(topic_id, part)');
            await db.execute('CREATE INDEX idx_matching_options_question ON MatchingOptions(question_id)');
            await db.execute('CREATE INDEX idx_matching_answers_question ON MatchingAnswers(question_id)');

            // Мигрируем старые данные в новую структуру если нужно
            for (var oldQuestion in oldQuestions) {
              await db.insert('Questions', {
                'topic_id': oldQuestion['topic_id'],
                'part': 'A', // Предполагаем, что все старые вопросы относятся к части A
                'question_text': oldQuestion['question_text'],
                'question_type': 'single_word',
                'correct_answer': oldQuestion['correct_answer'],
                'max_words': 1,
              });
            }
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

  Future<int> insertPartAQuestion(
      int topicId, 
      String questionText, 
      String questionType, 
      String correctAnswer, 
      {int maxWords = 1, String? imagePath}) async {
    final db = await database;
    return await db.insert(
      'Questions',
      {
        'topic_id': topicId,
        'part': 'A',
        'question_text': questionText,
        'question_type': questionType,
        'correct_answer': correctAnswer,
        'max_words': maxWords,
        'image_path': imagePath,
      },
    );
  }

  Future<void> insertPartBQuestion(
      int topicId,
      String questionText,
      List<Map<String, String>> leftItems,
      List<Map<String, String>> rightItems,
      List<Map<String, String>> answers,
      {String? imagePath}) async {
    final db = await database;
    await db.transaction((txn) async {
      // Вставляем вопрос с изображением
      final questionId = await txn.insert(
        'Questions',
        {
          'topic_id': topicId,
          'part': 'B',
          'question_text': questionText,
          'question_type': 'matching',
          'image_path': imagePath,
        },
      );

      // Вставляем элементы левой колонки
      for (var item in leftItems) {
        await txn.insert(
          'MatchingOptions',
          {
            'question_id': questionId,
            'item_text': item['text'],
            'item_group': 'left',
            'item_index': item['index'],
          },
        );
      }

      // Вставляем элементы правой колонки
      for (var item in rightItems) {
        await txn.insert(
          'MatchingOptions',
          {
            'question_id': questionId,
            'item_text': item['text'],
            'item_group': 'right',
            'item_index': item['index'],
          },
        );
      }

      // Вставляем правильные соответствия
      for (var answer in answers) {
        await txn.insert(
          'MatchingAnswers',
          {
            'question_id': questionId,
            'left_item_index': answer['left'],
            'right_item_index': answer['right'],
          },
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> getQuestionsByPart(int topicId, String part) async {
    final db = await database;
    return await db.query(
      'Questions',
      where: 'topic_id = ? AND part = ?',
      whereArgs: [topicId, part],
    );
  }

  Future<Map<String, List<Map<String, dynamic>>>> getMatchingOptions(int questionId) async {
    final db = await database;
    final options = await db.query(
      'MatchingOptions',
      where: 'question_id = ?',
      whereArgs: [questionId],
    );

    return {
      'left': options.where((o) => o['item_group'] == 'left').toList(),
      'right': options.where((o) => o['item_group'] == 'right').toList(),
    };
  }

  Future<List<Map<String, dynamic>>> getMatchingAnswers(int questionId) async {
    final db = await database;
    return await db.query(
      'MatchingAnswers',
      where: 'question_id = ?',
      whereArgs: [questionId],
    );
  }
}