import 'package:flutter/material.dart';
import 'dart:ui'; // Для использования ImageFilter.blur
import 'topic_screen.dart';
import '../database.dart';
import '../services/test_progress_service.dart';

class CategoriesScreen extends StatefulWidget {
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
  _CategoriesScreenState createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  List<Map<String, dynamic>> _topics = [];
  List<Map<String, dynamic>> _filteredTopics = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTopics();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTopics() async {
    final topics = await DBProvider.db.getTopicsByChapter(widget.chapterId);
    setState(() {
      _topics = topics;
      _filteredTopics = topics;
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    setState(() {
      _filteredTopics = _topics
          .where((topic) =>
          topic['title'].toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.chapterTitle,
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
      body: Stack(
        children: [
          // Фоновое изображение с размытием
          Positioned.fill(
            child: Image.asset(
              widget.chapterImage,
              fit: BoxFit.cover,
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Container(
              color: Colors.black.withOpacity(0.5),
            ),
          ),
          // Основной контент
          Column(
            children: [
              // Поле поиска
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Поиск по темам...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                      prefixIcon: Icon(Icons.search, color: Colors.white),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ),
              // Список тем
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.all(16.0),
                  itemCount: _filteredTopics.length,
                  itemBuilder: (context, index) {
                    final topic = _filteredTopics[index];
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
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopicCard(BuildContext context, Map<String, dynamic> topic) {
    return Card(
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Тема ${topic['id']}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Text(
              topic['title'],
              style: TextStyle(
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
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: double.infinity, // Занимает всю ширину
              child: Image.asset(
                topic['image_path'],
                fit: BoxFit.fitWidth, // Растягивается по ширине, сохраняя пропорции
                errorBuilder: (context, error, stackTrace) {
                  print('Ошибка загрузки изображения: $error');
                  return Center(
                    child: Icon(
                      Icons.image_not_supported,
                      size: 50,
                      color: Colors.grey,
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Дополнительная информация о теме...',
                  style: TextStyle(
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          settings: RouteSettings(name: '/topic'),
                          pageBuilder: (context, animation, secondaryAnimation) => TopicScreen(
                            topicTitle: topic['title'],
                            topicId: topic['id'],
                            chapterImage: widget.chapterImage,
                          ),
                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
                            const begin = Offset(1.0, 0.0);
                            const end = Offset.zero;
                            const curve = Curves.ease;

                            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                            var offsetAnimation = animation.drive(tween);

                            return SlideTransition(
                              position: offsetAnimation,
                              child: child,
                            );
                          },
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF2F642D),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                    ),
                    child: Text(
                      'Перейти к теме',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestIndicator(int topicId) {
    return FutureBuilder<double?>(
      future: TestProgressService.getTestScore(topicId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildIndicator(Colors.red);
        }

        double score = snapshot.data!;
        if (score >= 90) {
          return _buildIndicator(Colors.green);
        } else {
          return _buildIndicator(Colors.orange);
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
      ),
    );
  }
}