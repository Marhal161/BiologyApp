import 'package:flutter/material.dart';
import 'topic_screen.dart';
import '../database.dart';

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
        title: Text(chapterTitle, style: TextStyle( color: Colors.white)),
        backgroundColor: Color(0xFF2F642D),
        iconTheme: const IconThemeData(color: Colors.white),
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
                return Column(
                  children: [
                    _buildCategoryCard(
                      topic['title'],
                      topic['image_path'],
                      topic['id'],
                      context,
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildCategoryCard(String title, String imageUrl, int topicId, BuildContext context) {
    return Card(
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TopicScreen(
                topicTitle: title,
                topicId: topicId,
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
                imageUrl,
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
                    'Тема ${topicId}',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
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
} 