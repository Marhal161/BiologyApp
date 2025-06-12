import 'package:flutter/material.dart';
import 'topic_screen.dart'; // Импортируем TopicScreen
import 'dart:convert';
import '../database.dart';
import 'dart:math' show min, max;

class ResultsScreen extends StatefulWidget {
  final String topicTitle;
  final List<Map<String, dynamic>> questions;
  final List<String?> userAnswers;

  const ResultsScreen({
    super.key,
    required this.topicTitle,
    required this.questions,
    required this.userAnswers,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  List<bool> answerResults = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAnswers();
  }

  Future<void> _checkAnswers() async {
    List<bool> results = [];

    for (int i = 0; i < widget.questions.length; i++) {
      final question = widget.questions[i];
      final userAnswer = widget.userAnswers[i];
      final questionType = question['question_type'] as String?;

      if (questionType == 'matching') {
        try {
          if (userAnswer == null) {
            results.add(false);
            continue;
          }

          final userMatchingAnswers = json.decode(userAnswer) as Map<
              String,
              dynamic>;
          final correctMatchingAnswers = await DBProvider.db.getMatchingAnswers(
              question['id']);

          bool isCorrect = true;
          // Проверяем что количество соответствий совпадает
          if (correctMatchingAnswers.length != userMatchingAnswers.length) {
            isCorrect = false;
          } else {
            // Проверяем каждое соответствие
            for (var correctPair in correctMatchingAnswers) {
              final leftIndex = correctPair['left_item_index']
                  ?.toString(); // Приводим к строке
              final rightIndex = correctPair['right_item_index']
                  ?.toString(); // Приводим к строке

              // Проверяем есть ли такой ключ у пользователя
              if (leftIndex == null || rightIndex == null ||
                  !userMatchingAnswers.containsKey(leftIndex)) {
                isCorrect = false;
                break;
              }

              // Получаем ответ пользователя (может быть строкой или списком)
              dynamic userAnswerForLeft = userMatchingAnswers[leftIndex];

              // Если ответ пользователя - список, проверяем содержит ли он правильный ответ
              if (userAnswerForLeft is List) {
                if (!userAnswerForLeft.contains(rightIndex)) {
                  isCorrect = false;
                  break;
                }
              }
              // Если ответ пользователя - строка, просто сравниваем
              else if (userAnswerForLeft.toString() != rightIndex) {
                isCorrect = false;
                break;
              }
            }
          }
          results.add(isCorrect);
        } catch (e) {
          results.add(false);
        }
      } else if (questionType == 'multi_choice') {
        // Проверка для вопросов с множественным выбором
        final correctAnswer = question['correct_answer'];

        if (userAnswer != null && correctAnswer != null) {
          // Преобразуем ответы в наборы букв для сравнения без учета порядка
          final userLetters = userAnswer.split('')
            ..sort();
          final correctLetters = correctAnswer.toString().split('')
            ..sort();

          // Сравниваем отсортированные наборы букв
          results.add(userLetters.join() == correctLetters.join());
        } else {
          results.add(false);
        }
      } else {
        // Проверка для обычных вопросов (single_word, two_words, number)
        final correctAnswer = question['correct_answer'];

        if (userAnswer != null && correctAnswer != null) {
          // Проверяем, содержит ли правильный ответ символ "/"
          if (correctAnswer.toString().contains('/')) {
            // Разбиваем правильный ответ на несколько вариантов
            final acceptableAnswers = correctAnswer.toString().split('/')
                .map((answer) => answer.trim().toUpperCase())
                .toList();

            // Проверяем, является ли ответ пользователя формой любого из вариантов
            bool isAnyMatch = false;
            final userAnswerUpper = userAnswer.trim().toUpperCase();

            for (var answer in acceptableAnswers) {
              if (_isWordFormMatch(userAnswerUpper, answer)) {
                isAnyMatch = true;
                break;
              }
            }
            results.add(isAnyMatch);
          } else {
            // Обычная проверка для одного правильного ответа
            final userAnswerUpper = userAnswer.trim().toUpperCase();
            final correctAnswerUpper = correctAnswer.toString().trim().toUpperCase();

            // Используем улучшенный алгоритм для проверки падежей
            results.add(_isWordFormMatch(userAnswerUpper, correctAnswerUpper));
          }
        } else {
          results.add(false);
        }
      }
    }

    if (mounted) {
      setState(() {
        answerResults = results;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Подсчет правильных ответов
    int correctAnswers = answerResults
        .where((result) => result)
        .length;
    double percentage = widget.questions.isEmpty
        ? 0
        : (correctAnswers / widget.questions.length) * 100;

    return Scaffold(
      appBar: null, //
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: Image.asset("assets/images/backgroundfirstchapter.jpg").image,
            fit: BoxFit.cover,
          ),
        ),
        child: isLoading
            ? const Center(
            child: CircularProgressIndicator(color: Color(0xFF42A5F5)))
            : Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Заголовок и кнопка возврата
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      widget.topicTitle,
                      style: const TextStyle(
                        fontSize: 20,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black38,
                            offset: Offset(0, 1),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48), // Для симметрии
                ],
              ),
              const SizedBox(height: 10),
              // Результаты теста
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Результаты теста',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Правильных ответов: $correctAnswers из ${widget.questions.length}',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Процент правильных ответов: ${percentage.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 15),
                    // Добавляем мотивационное сообщение
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getMotivationColor(percentage),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getMotivationIcon(percentage),
                            color: Colors.white,
                            size: 28,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _getMotivationMessage(percentage),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Список вопросов и ответов
              Expanded(
                child: ListView.builder(
                  itemCount: widget.questions.length,
                  itemBuilder: (context, index) {
                    final question = widget.questions[index];
                    final userAnswer = widget.userAnswers[index];
                    final isCorrect = index < answerResults.length ? answerResults[index] : false;
                    final questionType = question['question_type'] as String?;

                    // Упрощенная версия карточки вопроса
                    return Card(
                      color: Colors.white.withOpacity(0.7),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ExpansionTile(
                        collapsedIconColor: Colors.black87,
                        iconColor: Colors.black87,
                        leading: Icon(
                          isCorrect ? Icons.check_circle : Icons.cancel,
                          color: isCorrect ? Colors.green : Colors.red,
                          size: 28,
                        ),
                        title: Text(
                          'Вопрос ${index + 1}',
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          _getShortQuestionText(question['question_text'] ?? ''),
                          style: const TextStyle(
                            color: Colors.black54,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        expandedCrossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  question['question_text'] ?? 'Вопрос без текста',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                // Добавляем проверку на тип вопроса
                                if (questionType == 'matching')
                                  FutureBuilder(
                                    future: _buildMatchingDetails(question, userAnswer),
                                    builder: (context, snapshot) {
                                      if (!snapshot.hasData) {
                                        return const Center(
                                          child: CircularProgressIndicator(color: Color(0xFF42A5F5)),
                                        );
                                      }
                                      return snapshot.data!;
                                    },
                                  )
                                else
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Ваш ответ:',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isCorrect ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          userAnswer ?? 'Нет ответа',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: isCorrect ? Colors.green : Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          softWrap: true,
                                          overflow: TextOverflow.visible,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      if (!isCorrect)
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Правильный ответ:',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black54,
                                              ),
                                            ),
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.green.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                _formatCorrectAnswer(question),
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.green,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                softWrap: true,
                                                overflow: TextOverflow.visible,
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF42A5F5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text(
                    'Вернуться к вопросам',
                    style: TextStyle(
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Улучшенный метод форматирования ответов
  String _formatCorrectAnswer(Map<String, dynamic> question) {
    final questionType = question['question_type'] as String?;
    final correctAnswer = question['correct_answer'];

    if (questionType == null || correctAnswer == null) {
      return 'Нет правильного ответа';
    }

    if (questionType == 'multi_choice') {
      // Для вопросов с множественным выбором форматируем буквы (например, "А, Б, В")
      final letters = correctAnswer.toString().split('');
      return letters.join(', ');
    }

    if (questionType == 'matching') {
      // Этот блок не должен выполняться, так как для matching используется _buildMatchingDetails
      return 'Смотрите детали выше';
    }

    // Для вопросов с несколькими правильными ответами
    if (correctAnswer.toString().contains('/')) {
      // Заменяем "/" на "или" для более понятного отображения
      final acceptableAnswers = correctAnswer.toString().split('/')
          .map((answer) => answer.trim())
          .join(' или ');
      return acceptableAnswers;
    }

    // Для всех остальных типов вопросов
    return correctAnswer.toString();
  }

  // Получить сокращенный текст вопроса для подзаголовка
  String _getShortQuestionText(String text) {
    // Если текст содержит переносы строк, берем только первую строку
    if (text.contains('\n')) {
      return text.split('\n').first;
    }
    // Иначе ограничиваем длину текста
    return text.length > 50 ? '${text.substring(0, 47)}...' : text;
  }

  // Отображение деталей для вопросов с сопоставлением
  Future<Widget> _buildMatchingDetails(Map<String, dynamic> question, String? userAnswer) async {
    try {
      // Оптимизация: загружаем данные более эффективно
      final questionId = question['id'];
      // Одновременно запускаем оба запроса
      final optionsFuture = DBProvider.db.getMatchingOptions(questionId);
      final correctAnswersFuture = DBProvider.db.getMatchingAnswers(questionId);

      // Ждем завершения обоих запросов
      final options = await optionsFuture;
      final correctAnswers = await correctAnswersFuture;

      // Быстрая проверка на пустые данные
      if (options['left'] == null || options['right'] == null || correctAnswers.isEmpty) {
        return _buildErrorWidget('Данные вопроса повреждены');
      }

      // Создаем словари для быстрого доступа
      final leftOptions = {
        for (var item in options['left']!)
          item['item_index']?.toString() ?? '?': item['item_text']?.toString() ?? ''
      };

      final rightOptions = {
        for (var item in options['right']!)
          item['item_index']?.toString() ?? '?': item['item_text']?.toString() ?? ''
      };

      // Карта правильных ответов (учитываем множественные соответствия)
      final correctMap = <String, List<String>>{};
      for (var answer in correctAnswers) {
        final leftKey = answer['left_item_index']?.toString();
        final rightKey = answer['right_item_index']?.toString();
        if (leftKey != null && rightKey != null) {
          correctMap[leftKey] ??= [];
          correctMap[leftKey]!.add(rightKey);
        }
      }

      // Парсим ответ пользователя с защитой от ошибок
      Map<String, dynamic> userAnswersMap = {};
      if (userAnswer != null && userAnswer.isNotEmpty) {
        userAnswersMap = json.decode(userAnswer) as Map<String, dynamic>;
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ваши соответствия:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          ...correctMap.keys.map((leftKey) {
            final userRightKeys = _convertUserAnswer(userAnswersMap[leftKey]);
            final correctRightKeys = correctMap[leftKey] ?? [];
            final isMatch = _compareAnswers(userRightKeys, correctRightKeys);

            return _buildMatchRow(
              leftKey: leftKey,
              leftText: leftOptions[leftKey] ?? '',
              userRightKeys: userRightKeys,
              correctRightKeys: correctRightKeys,
              rightOptions: rightOptions,
              isMatch: isMatch,
            );
          }).toList(),
        ],
      );
    } catch (e) {
      return _buildErrorWidget('Ошибка загрузки данных');
    }
  }

  // Вспомогательные методы:

  Widget _buildErrorWidget(String message) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        message,
        style: const TextStyle(color: Colors.red),
      ),
    );
  }

  List<String> _convertUserAnswer(dynamic answer) {
    if (answer == null) return [];
    if (answer is List) return answer.map((e) => e.toString()).toList();
    return [answer.toString()];
  }

  bool _compareAnswers(List<String> userAnswers, List<String> correctAnswers) {
    if (userAnswers.length != correctAnswers.length) return false;
    return userAnswers.every((answer) => correctAnswers.contains(answer));
  }

  Widget _buildMatchRow({
    required String leftKey,
    required String leftText,
    required List<String> userRightKeys,
    required List<String> correctRightKeys,
    required Map<String, String> rightOptions,
    required bool isMatch,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$leftKey) $leftText',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          _buildAnswerSection(
            title: 'Ваш выбор:',
            keys: userRightKeys,
            options: rightOptions,
            isCorrect: isMatch,
          ),
          if (!isMatch) ...[
            const SizedBox(height: 4),
            _buildAnswerSection(
              title: 'Правильно:',
              keys: correctRightKeys,
              options: rightOptions,
              isCorrect: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnswerSection({
    required String title,
    required List<String> keys,
    required Map<String, String> options,
    required bool isCorrect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.black.withOpacity(0.6),
          ),
        ),
        ...keys.map((key) =>
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCorrect
                      ? Colors.green.withOpacity(0.2)
                      : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$key) ${options[key] ?? ''}',
                  style: TextStyle(
                    color: isCorrect ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            )),
      ],
    );
  }

  // Метод для проверки форм слова
  bool _isWordFormMatch(String userWord, String correctWord) {
    // Прямая проверка для случая "Гладкой ЭПС"/"Гладкая ЭПС" и подобных
    if (_isSpecificCase(userWord, correctWord)) {
      return true;
    }

    // Нормализуем слова и приводим к нижнему регистру
    String normalizedUserWord = _normalizeWord(userWord.toLowerCase());
    String normalizedCorrectWord = _normalizeWord(correctWord.toLowerCase());

    // Специальная обработка для сочетаний слов с аббревиатурами (гладкая ЭПС/гладкой ЭПС)
    if (_containsAbbreviation(userWord) && _containsAbbreviation(correctWord)) {
      // Извлекаем аббревиатуры (сохраняем регистр для точного сравнения)
      List<String> abbrsUser = _extractAbbreviations(userWord);
      List<String> abbrsCorrect = _extractAbbreviations(correctWord);

      // Проверяем совпадение аббревиатур
      bool abbrsMatch = _listsHaveCommonElements(abbrsUser, abbrsCorrect);

      if (abbrsMatch) {
        // Удаляем аббревиатуры из текста и проверяем остальную часть
        String userWithoutAbbrs = _removeAbbreviations(normalizedUserWord, abbrsUser.map((a) => a.toLowerCase()).toList());
        String correctWithoutAbbrs = _removeAbbreviations(normalizedCorrectWord, abbrsCorrect.map((a) => a.toLowerCase()).toList());

        // Очищаем от пробелов, запятых и т.д.
        userWithoutAbbrs = userWithoutAbbrs.replaceAll(RegExp(r'[,\s\.\-]'), '');
        correctWithoutAbbrs = correctWithoutAbbrs.replaceAll(RegExp(r'[,\s\.\-]'), '');

        // Проверяем на точное совпадение после удаления аббревиатур
        if (userWithoutAbbrs == correctWithoutAbbrs) {
          return true;
        }

        // Проверяем на разные падежи оставшейся части
        if (_checkWordForms(userWithoutAbbrs, correctWithoutAbbrs)) {
          return true;
        }

        // Специальная проверка для прилагательных перед аббревиатурами
        if (_checkAdjectiveWithAbbreviation(userWord, correctWord)) {
          return true;
        }
      }
    }

    // Удаляем пробелы, запятые и другие знаки пунктуации
    normalizedUserWord = normalizedUserWord.replaceAll(RegExp(r'[,\s\.\-]'), '');
    normalizedCorrectWord = normalizedCorrectWord.replaceAll(RegExp(r'[,\s\.\-]'), '');

    // 1. Точное совпадение после нормализации
    if (normalizedUserWord == normalizedCorrectWord) {
      return true;
    }

    // 2. Универсальная проверка на различные формы слов
    return _checkWordForms(normalizedUserWord, normalizedCorrectWord);
  }

  // Проверка для конкретных частых случаев
  bool _isSpecificCase(String userAnswer, String correctAnswer) {
    // Нормализуем регистр, но сохраняем пробелы и структуру
    String userLower = userAnswer.toLowerCase();
    String correctLower = correctAnswer.toLowerCase();

    // Создаем набор известных пар "правильный ответ" <-> "допустимый вариант"
    Map<String, List<String>> knownPairs = {
      'гладкой эпс': ['гладкая эпс', 'гладкая епс', 'гладкий эпс'],
      'гладкая эпс': ['гладкой эпс', 'гладкой епс', 'гладкий эпс'],
      'шероховатой эпс': ['шероховатая эпс', 'шероховатый эпс'],
      'шероховатая эпс': ['шероховатой эпс', 'шероховатый эпс'],
      'гладкий эпс': ['гладкая эпс', 'гладкой эпс'],
      'шероховатый эпс': ['шероховатая эпс', 'шероховатой эпс'],
      'красная кровь': ['красной крови', 'красной кровью'],
      'красной крови': ['красная кровь', 'красной кровью'],
    };

    // Проверяем, есть ли правильный ответ в нашем словаре
    if (knownPairs.containsKey(correctLower)) {
      // Проверяем, является ли ответ пользователя допустимым вариантом
      if (knownPairs[correctLower]!.contains(userLower)) {
        return true;
      }
    }

    // И в обратном порядке
    if (knownPairs.containsKey(userLower)) {
      if (knownPairs[userLower]!.contains(correctLower)) {
        return true;
      }
    }

    // Универсальная проверка для пар вида "прилагательное + аббревиатура"
    if (_containsAbbreviation(userAnswer) && _containsAbbreviation(correctAnswer)) {
      List<String> userWords = userLower.split(RegExp(r'\s+'));
      List<String> correctWords = correctLower.split(RegExp(r'\s+'));

      // Если в обоих ответах по 2 слова
      if (userWords.length == 2 && correctWords.length == 2) {
        // Если второе слово совпадает (вероятно, это аббревиатура)
        if (userWords[1] == correctWords[1]) {
          // Проверяем первое слово на известные окончания прилагательных
          String userAdj = userWords[0];
          String correctAdj = correctWords[0];

          // Известные пары окончаний для прилагательных женского рода
          List<List<String>> relatedEndings = [
            ['ая', 'ой', 'ую', 'ой'],     // красная/красной/красную
            ['яя', 'ей', 'юю', 'ей'],     // синяя/синей/синюю
            ['ой', 'ая', 'ую', 'ой'],     // красной/красная/красную
            ['ей', 'яя', 'юю', 'ей'],     // синей/синяя/синюю
          ];

          // Проверяем, заканчивается ли прилагательное на известные окончания
          for (var pair in relatedEndings) {
            if (userAdj.endsWith(pair[0]) && correctAdj.endsWith(pair[1])) {
              return true;
            }
            if (userAdj.endsWith(pair[1]) && correctAdj.endsWith(pair[0])) {
              return true;
            }
          }
        }
      }
    }

    return false;
  }

  // Проверяет соответствие прилагательного перед аббревиатурой
  bool _checkAdjectiveWithAbbreviation(String userAnswer, String correctAnswer) {
    // Разбиваем ответы на слова
    List<String> userWords = userAnswer.split(RegExp(r'\s+'));
    List<String> correctWords = correctAnswer.split(RegExp(r'\s+'));

    // Если оба ответа содержат минимум по 2 слова
    if (userWords.length >= 2 && correctWords.length >= 2) {
      // Проверяем только первое слово (обычно прилагательное) и аббревиатуру
      String userFirstWord = userWords[0].toLowerCase();
      String correctFirstWord = correctWords[0].toLowerCase();

      // Проверяем, что второе слово (аббревиатура) совпадает
      bool abbrMatch = false;
      for (int i = 1; i < min(userWords.length, correctWords.length); i++) {
        if (userWords[i].toUpperCase() == correctWords[i].toUpperCase()) {
          abbrMatch = true;
          break;
        }
      }

      if (abbrMatch) {
        // Проверяем падежи прилагательного
        // Группы связанных окончаний для женского рода
        List<List<String>> femEndings = [
          ['ая', 'ой', 'ую'],    // красная, красной, красную
          ['яя', 'ей', 'юю'],    // синяя, синей, синюю
        ];

        // Проверяем на соответствие известным формам
        for (var endings in femEndings) {
          for (String ending1 in endings) {
            if (userFirstWord.endsWith(ending1)) {
              for (String ending2 in endings) {
                if (correctFirstWord.endsWith(ending2)) {
                  return true;
                }
              }
            }
          }
        }
      }
    }

    return false;
  }

  // Проверяет, содержит ли строка аббревиатуру (заглавные буквы подряд)
  bool _containsAbbreviation(String text) {
    // Ищем группы из 2+ заглавных букв
    return RegExp(r'[А-ЯA-Z]{2,}').hasMatch(text);
  }

  // Извлекает все аббревиатуры из строки
  List<String> _extractAbbreviations(String text) {
    List<String> result = [];
    RegExp regExp = RegExp(r'[А-ЯA-Z]{2,}');

    for (Match match in regExp.allMatches(text)) {
      result.add(match.group(0)!);
    }

    return result;
  }

  // Удаляет все аббревиатуры из строки
  String _removeAbbreviations(String text, List<String> abbreviations) {
    String result = text;
    for (String abbr in abbreviations) {
      result = result.replaceAll(abbr, ' ');
    }
    // Удаляем лишние пробелы
    return result.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  // Проверяет, есть ли общие элементы в двух списках
  bool _listsHaveCommonElements(List<String> list1, List<String> list2) {
    for (String item in list1) {
      if (list2.contains(item)) {
        return true;
      }
    }
    return false;
  }

  // Универсальный метод для проверки различных форм слов (существительных, прилагательных, причастий)
  bool _checkWordForms(String word1, String word2) {
    // Слишком короткие слова не сравниваем
    if (word1.length < 3 || word2.length < 3) return false;

    // Слишком разные по длине слова скорее всего не связаны
    if ((word1.length - word2.length).abs() > 5) return false;

    // 0. Специальная проверка для существительных множественного числа (надпочечники/надпочечниками)
    if (word1.length > 8 && word2.length > 8) {
      // Определяем минимальную длину общей основы для длинных слов
      int commonLength = min(word1.length, word2.length) - 5;
      commonLength = max(6, commonLength); // Не менее 6 символов для основы

      // Проверяем, совпадает ли основа
      if (word1.substring(0, commonLength) == word2.substring(0, commonLength)) {
        // Проверяем известные окончания множественного числа существительных
        List<String> pluralNounEndings = [
          'и', 'ы',                  // Именительный (надпочечники)
          'ов', 'ев', 'ей',          // Родительный (надпочечников)
          'ам', 'ям',                // Дательный (надпочечникам)
          'и', 'ы', 'ей', 'ов',      // Винительный (надпочечники)
          'ами', 'ями', 'ьми',       // Творительный (надпочечниками)
          'ах', 'ях'                 // Предложный (надпочечниках)
        ];

        // Группы связанных окончаний существительных множественного числа
        List<List<String>> relatedPluralEndings = [
          ['и', 'ов', 'ам', 'ами', 'ах'],    // твердая основа (надпочечники, надпочечников...)
          ['ы', 'ов', 'ам', 'ами', 'ах'],    // твердая основа (мосты, мостов...)
          ['и', 'ей', 'ям', 'ями', 'ях'],    // мягкая основа (кости, костей...)
          ['ы', 'ей', 'ам', 'ами', 'ах']     // смешанная (цепи, цепей...)
        ];

        // Проверяем окончания
        String ending1 = word1.substring(word1.length - min(4, word1.length));
        String ending2 = word2.substring(word2.length - min(4, word2.length));

        // Проверяем основные окончания
        for (String ending in pluralNounEndings) {
          if (word1.endsWith(ending) && word2.endsWith(ending)) {
            return true; // Одинаковые окончания
          }
        }

        // Проверяем связанные окончания одной группы
        for (var group in relatedPluralEndings) {
          bool ending1InGroup = false;
          bool ending2InGroup = false;

          for (String ending in group) {
            if (word1.endsWith(ending)) ending1InGroup = true;
            if (word2.endsWith(ending)) ending2InGroup = true;
          }

          if (ending1InGroup && ending2InGroup) {
            return true; // Оба окончания из одной группы
          }
        }

        // Специальная проверка для именительного/творительного падежа (надпочечники/надпочечниками)
        if ((word1.endsWith('и') || word1.endsWith('ы')) &&
            (word2.endsWith('ами') || word2.endsWith('ями'))) {
          return true;
        }

        // И в обратном порядке
        if ((word2.endsWith('и') || word2.endsWith('ы')) &&
            (word1.endsWith('ами') || word1.endsWith('ями'))) {
          return true;
        }
      }
    }

    // 1. Прилагательные и причастия (длинные слова)
    if (word1.length >= 5 && word2.length >= 5) {
      // Основа должна быть минимум 5 символов
      int stemLength = min(min(word1.length, word2.length) - 2, word1.length - 2);
      stemLength = max(5, stemLength);

      if (stemLength <= word1.length && stemLength <= word2.length) {
        // Проверяем совпадение основы
        if (word1.substring(0, stemLength) == word2.substring(0, stemLength)) {
          // Извлекаем окончания
          String ending1 = word1.length > stemLength ? word1.substring(stemLength) : "";
          String ending2 = word2.length > stemLength ? word2.substring(stemLength) : "";

          // Все возможные окончания прилагательных и причастий
          List<String> adjEndings = [
            'ый', 'ой', 'ий', 'ая', 'яя', 'ое', 'ее',   // именительный
            'ого', 'его', 'ой', 'ей',                   // родительный
            'ому', 'ему', 'ой', 'ей',                   // дательный 
            'ый', 'ой', 'ий', 'ую', 'юю', 'ое', 'ее',   // винительный
            'ым', 'им', 'ой', 'ей',                     // творительный
            'ом', 'ем', 'ой', 'ей',                     // предложный
            'ые', 'ие', 'ых', 'их', 'ым', 'им', 'ыми', 'ими',  // множественное число
            'ен', 'ена', 'ено', 'ены',                  // краткие формы
            'ее', 'ей', 'ейш', 'айш'                    // сравнительные степени
          ];
          
          // Группы окончаний, которые связаны между собой (формы одного падежа)
          List<List<String>> relatedGroups = [
            ['ый', 'ом', 'ому', 'ого', 'ым'],  // мужской род, ед. число (продолговатый, продолговатом...)
            ['ий', 'ем', 'ему', 'его', 'им'],  // мужской род, мягкий вариант (синий, синем...)
            ['ая', 'ой', 'ую'],                // женский род (красная, красной, красную)
            ['яя', 'ей', 'юю'],                // женский род, мягкий вариант (синяя, синей, синюю)
            ['ое', 'ом', 'ому', 'ого'],        // средний род (зеленое, зеленом...)
            ['ее', 'ем', 'ему', 'его'],        // средний род, мягкий вариант (синее, синем...)
            ['ые', 'ых', 'ым', 'ыми'],         // множественное число (красные, красных...)
            ['ие', 'их', 'им', 'ими'],         // множественное число, мягкий вариант (синие, синих...)
            ['щие', 'щих', 'щим', 'щими'],     // причастия мн. число (говорящие, говорящих...)
            ['ий', 'ый', 'ом', 'ем', 'ым', 'им'] // смешанная группа для мужского рода
          ];
          
          // Проверка на принадлежность к известным окончаниям
          if (adjEndings.contains(ending1) && adjEndings.contains(ending2)) {
            // Проверка на принадлежность к одной группе падежных форм
            for (var group in relatedGroups) {
              if (group.contains(ending1) && group.contains(ending2)) {
                return true;
              }
            }
            
            // Дополнительная проверка для случаев, не попавших в группы
            if ((ending1.length <= 3 && ending2.length <= 3) && 
                (word1.length - word2.length).abs() <= 3) {
              // Для случаев как "продолговатый"/"продолговатом"
              if ((ending1 == 'ый' || ending1 == 'ий' || ending1 == 'ой') && 
                  (ending2 == 'ом' || ending2 == 'ем' || ending2 == 'ым' || ending2 == 'им')) {
                return true;
              }
              
              // И в обратном порядке
              if ((ending2 == 'ый' || ending2 == 'ий' || ending2 == 'ой') && 
                  (ending1 == 'ом' || ending1 == 'ем' || ending1 == 'ым' || ending1 == 'им')) {
                return true;
              }
            }
          }
        }
      }
    }
    
    // 2. Существительные (короткие и средние слова)
    // Используем более короткую основу для существительных
    int rootLength = min(min(word1.length, word2.length) - 1, 5);
    rootLength = max(3, rootLength);
    
    if (word1.substring(0, rootLength) == word2.substring(0, rootLength)) {
      // Разница в длине не должна быть большой для форм одного слова
      if ((word1.length - word2.length).abs() <= 3) {
        // Известные пары окончаний существительных
        Map<String, List<String>> nounForms = {
          'о': ['а', 'у', 'ом', 'е'],   // железо -> железа, железу, железом, железе
          'а': ['о', 'у', 'ом', 'е'],   // железа -> железо, железу, железом, железе
          'я': ['е', 'ю', 'ем', 'и'],   // доля -> доле, долю, долей
          'ь': ['я', 'ю', 'ем', 'и'],   // конь -> коня, коню, конем
          'й': ['я', 'ю', 'ем', 'и'],   // край -> края, краю, краем
          'е': ['я', 'ю', 'ем'],        // поле -> поля, полю, полем
        };
        
        // Особые случаи существительных
        // О/А пары (железо/железа)
        if ((word1.endsWith('о') && word2.endsWith('а')) || 
            (word1.endsWith('а') && word2.endsWith('о'))) {
          return true;
        }
        
        // Проверка по таблице окончаний
        if (word1.length > 0 && word2.length > 0) {
          String ending1 = word1.substring(word1.length - 1);
          String ending2 = word2.substring(word2.length - 1);
          
          // Проверяем первое слово
          if (nounForms.containsKey(ending1) && 
              nounForms[ending1]!.any((e) => word2.endsWith(e))) {
            return true;
          }
          
          // Проверяем второе слово
          if (nounForms.containsKey(ending2) && 
              nounForms[ending2]!.any((e) => word1.endsWith(e))) {
            return true;
          }
        }
      }
    }
    
    // 3. Особые случаи для длинных слов (причастия, составные слова)
    if (word1.length > 10 && word2.length > 10) {
      // Проверяем совпадение первой половины длинного слова
      int halfLength = min(word1.length, word2.length) ~/ 2;
      if (word1.substring(0, halfLength) == word2.substring(0, halfLength)) {
        // Проверка известных окончаний причастий и длинных прилагательных
        List<String> specialEndings = [
          'щие', 'щих', 'щим', 'щими', 'вшие', 'вших',  // причастия
          'ющие', 'ющих', 'ющим', 'ющими', 'ющий', 'ющего', 'ющему', 'ющим', 'ющем',  // действительные причастия
          'емые', 'емых', 'емым', 'емыми', 'емый', 'емого', 'емому', 'емым', 'емом'   // страдательные причастия
        ];
        
        // Проверка на наличие специальных окончаний
        for (String ending in specialEndings) {
          if ((word1.endsWith(ending) || word2.endsWith(ending)) && 
              (word1.length - word2.length).abs() <= ending.length + 2) {
            return true;
          }
        }
        
        // Специальный случай для "двоякодышащие"/"двоякодышащих"
        if ((word1.contains('дыша') && word2.contains('дыша')) ||
            (word1.contains('якод') && word2.contains('якод'))) {
          if ((word1.endsWith('ие') && word2.endsWith('их')) || 
              (word1.endsWith('их') && word2.endsWith('ие'))) {
            return true;
          }
        }
      }
    }
    
    return false;
  }

  // Метод для нормализации слова (замена 'ё' на 'е')
  String _normalizeWord(String word) {
    return word.replaceAll('Ё', 'Е').replaceAll('ё', 'е');
  }
  
  // Получаем мотивационное сообщение в зависимости от процента правильных ответов
  String _getMotivationMessage(double percentage) {
    if (percentage == 0) {
      return 'Не отчаивайся! В следующий раз получится лучше.';
    } else if (percentage < 30) {
      return 'Ты можешь лучше! Повтори материал и попробуй снова.';
    } else if (percentage < 50) {
      return 'Неплохое начало! Еще немного усилий, и будет хороший результат.';
    } else if (percentage < 70) {
      return 'Хороший результат! Ты на верном пути.';
    } else if (percentage < 90) {
      return 'Отличная работа! Ты почти у цели!';
    } else if (percentage < 100) {
      return 'Превосходно! Ты очень хорошо разбираешься в теме!';
    } else {
      return 'Великолепно! Ты настоящий знаток биологии!';
    }
  }
  
  // Получаем цвет для мотивационного сообщения
  Color _getMotivationColor(double percentage) {
    if (percentage < 30) {
      return Colors.red.shade700.withOpacity(0.8);
    } else if (percentage < 70) {
      return Colors.orange.shade700.withOpacity(0.8);
    } else {
      return Colors.green.shade700.withOpacity(0.8);
    }
  }
  
  // Получаем иконку для мотивационного сообщения
  IconData _getMotivationIcon(double percentage) {
    if (percentage < 30) {
      return Icons.sentiment_dissatisfied;
    } else if (percentage < 70) {
      return Icons.sentiment_neutral;
    } else if (percentage < 100) {
      return Icons.sentiment_satisfied;
    } else {
      return Icons.emoji_events;
    }
  }
}