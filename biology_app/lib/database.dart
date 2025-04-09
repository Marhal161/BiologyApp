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
      // Если файл не существует, создаем пустую базу данных
      // При использовании database.db этот код не выполнится, 
      // так как мы скопируем готовую базу данных из assets
      return await openDatabase(path);
    } else {
      // Если файл существует, просто открываем его
      return await openDatabase(path);
    }
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
      
    } catch (e) {}
  }

  // Методы для получения данных из базы данных
  
  Future<List<Map<String, dynamic>>> getQuestionsByTopicId(int topicId) async {
    final db = await database;
    return await db.query(
      'Questions',
      where: 'topic_id = ?',
      whereArgs: [topicId],
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
  
  // Метод для обновления вопросов с несколькими правильными ответами
  Future<void> updateQuestionWithMultipleAnswers(int questionId, String correctAnswer) async {
    final db = await database;
    await db.update(
      'Questions',
      {'correct_answer': correctAnswer},
      where: 'id = ?',
      whereArgs: [questionId],
    );
  }
}