import 'package:flutter/material.dart';
import 'topic_screen.dart';
import '../database.dart';
import '../services/test_progress_service.dart';

class CategoriesScreen extends StatelessWidget {
  final int chapterId;
  final String chapterTitle;
  final String chapterImage;

  const CategoriesScreen({
    super.key,
    required this.chapterId,
    required this.chapterTitle,
    required this.chapterImage,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(chapterTitle, style: TextStyle( color: Colors.white,
          shadows: [
          Shadow(
            color: Colors.black26,
            offset: Offset(0, 2),
            blurRadius: 10,
          ),
        ],)),
        backgroundColor: Color(0xFF2F642D),
        iconTheme: const IconThemeData(color: Colors.white,
          shadows: [
          Shadow(
            color: Colors.black26,
            offset: Offset(0, 2),
            blurRadius: 10,
          ),
        ],),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            colors: [Color(0xFF2F642D), Color(0xFF5A9647)],
            focal: Alignment.topRight,
            radius: 3.0,
          ),
        ),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: DBProvider.db.getTopicsByChapter(chapterId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Ошибка: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white),
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Text(
                  'Нет доступных тем',
                  style: TextStyle(color: Colors.white),
                ),
              );
            }

            final topics = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: topics.length,
              itemBuilder: (context, index) {
                final topic = topics[index];
                return Stack(
                  children: [
                    _buildTopicCard(context, topic),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: _buildTestIndicator(topic['id']),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopicCard(BuildContext context, Map<String, dynamic> topic) {
    return Card(
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TopicScreen(
                topicTitle: topic['title'],
                topicId: topic['id'],
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 200,
              child: Image.asset(
                topic['image_path'],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  print('Ошибка загрузки изображения: $error');
                  return const Center(
                    child: Icon(
                      Icons.image_not_supported,
                      size: 50,
                      color: Colors.grey,
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Тема ${topic['id']}',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    topic['title'],
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          offset: Offset(0, 2),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestIndicator(int topicId) {
    return FutureBuilder<double?>(
      future: TestProgressService.getTestScore(topicId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildIndicator(Colors.red); // Не пройден
        }
        
        double score = snapshot.data!;
        if (score >= 90) {
          return _buildIndicator(Colors.green); // Пройден на 90% и выше
        } else {
          return _buildIndicator(Colors.orange); // Пройден, но менее 90%
        }
      },
    );
  }

  Widget _buildIndicator(Color color) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
    );
  }
} 