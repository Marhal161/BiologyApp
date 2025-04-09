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
    
    // Проверяем, существует ли база данных в файловой системе устройства
    if (!await databaseExists(path)) {
      // Если не существует, копируем предварительно заполненную базу из assets
      try {
        // Убедитесь, что путь существует
        await Directory(dirname(path)).create(recursive: true);

        // Копируем из assets
        ByteData data = await rootBundle.load("assets/database/biology.db");
        List<int> bytes = data.buffer.asUint8List();
        await File(path).writeAsBytes(bytes, flush: true);
        
        print('База данных скопирована из ресурсов');
      } catch (e) {
        print('Ошибка при копировании базы данных: $e');
        // Если не удалось скопировать, создаем пустую базу
        return await openDatabase(
          path,
          version: 1,
          onCreate: (Database db, int version) async {
            // Создаем схему базы данных
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
          }
        );
      }
    }
    
    // Открываем базу данных с явным указанием режима чтения-записи
    return await openDatabase(
      path, 
      version: 1,
      readOnly: false,  // Явно указываем, что база не только для чтения
      onOpen: (db) {
        print('База данных успешно открыта в режиме чтения-записи');
      }
    );
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

  // Методы для получения данных из базы данных
  
  Future<List<Map<String, dynamic>>> getQuestionsByTopicId(int topicId) async {
    try {
      final db = await database;
      
      print('Запрос вопросов для темы с ID: $topicId');
      
      // Получаем общее количество вопросов для этой темы
      final countResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM Questions WHERE topic_id = ?',
        [topicId]
      );
      final count = Sqflite.firstIntValue(countResult) ?? 0;
      print('Всего вопросов для темы $topicId: $count');
      
      if (count == 0) {
        print('В базе данных нет вопросов для темы $topicId');
        // Проверим, существует ли сама тема
        final topicExists = await db.query(
          'Topics',
          where: 'id = ?',
          whereArgs: [topicId],
        );
        if (topicExists.isEmpty) {
          print('Тема с ID $topicId не найдена в базе данных!');
        }
      }
      
      // Получаем сами вопросы
      final questions = await db.query(
        'Questions',
        where: 'topic_id = ?',
        whereArgs: [topicId],
      );
      
      print('Успешно получено ${questions.length} вопросов');
      return questions;
    } catch (e) {
      print('Ошибка при получении вопросов: $e');
      return [];
    }
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

  // Функции для работы с главами
  Future<int> createChapter(Map<String, dynamic> chapter) async {
    final db = await database;
    return await db.insert('Chapters', chapter, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>> getChapter(int id) async {
    final db = await database;
    List<Map<String, dynamic>> result = await db.query(
      'Chapters',
      where: 'id = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty ? result.first : {};
  }

  // Функции для работы с темами
  Future<int> createTopic(Map<String, dynamic> topic) async {
    final db = await database;
    return await db.insert('Topics', topic, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>> getTopic(int id) async {
    final db = await database;
    List<Map<String, dynamic>> result = await db.query(
      'Topics',
      where: 'id = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty ? result.first : {};
  }

  // Функции для работы с вопросами
  Future<int> createQuestion(Map<String, dynamic> question) async {
    final db = await database;
    return await db.insert('Questions', question, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>> getQuestion(int id) async {
    final db = await database;
    List<Map<String, dynamic>> result = await db.query(
      'Questions',
      where: 'id = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty ? result.first : {};
  }

  // Обновление тестов
  Future<int> updateQuestion(Map<String, dynamic> question) async {
    final db = await database;
    return await db.update(
      'Questions',
      question,
      where: 'id = ?',
      whereArgs: [question['id']],
    );
  }

  // Удаление тестов
  Future<int> deleteQuestion(int id) async {
    final db = await database;
    return await db.delete(
      'Questions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Функция для проверки, заполнена ли база данных
  Future<bool> isDatabasePopulated() async {
    final db = await database;
    var count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM Chapters'));
    return count != null && count > 0;
  }
}