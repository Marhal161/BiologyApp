import 'package:flutter/material.dart';
import 'dart:ui';
import 'topic_screen.dart';
import '../database.dart';
import '../services/test_progress_service.dart';
import 'package:google_fonts/google_fonts.dart';

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
  CategoriesScreenState createState() => CategoriesScreenState();
}

class CategoriesScreenState extends State<CategoriesScreen> {
  List<Map<String, dynamic>> _topics = [];
  List<Map<String, dynamic>> _filteredTopics = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

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
    try {
      final topics = await DBProvider.db.getTopicsByChapter(widget.chapterId);
      setState(() {
        _topics = topics;
        _filteredTopics = topics;
        _isLoading = false;
      });
    } catch (e) {
      print('Ошибка при загрузке тем: $e');
      setState(() {
        _isLoading = false;
      });
    }
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
      body: Stack(
        children: [
          // Новый градиентный фон
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: Image.asset("assets/images/backgroundfirstchapter.jpg").image,
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Основной контент
          Column(
            children: [
              // Кнопка возврата и заголовок
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black87),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        widget.chapterTitle,
                        style: GoogleFonts.montserrat(
                          textStyle: TextStyle(
                            color: Colors.black87,
                            fontSize: 24,
                            fontWeight: FontWeight.w400,
                            shadows: [
                              Shadow(
                                color: Colors.white.withOpacity(0.5),
                                offset: const Offset(0, 2),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // Поле поиска
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.montserrat(
                      textStyle: const TextStyle(color: Colors.black87),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Поиск по темам...',
                      hintStyle: GoogleFonts.montserrat(
                        textStyle: TextStyle(color: Colors.black54),
                      ),
                      prefixIcon: const Icon(Icons.search, color: Colors.black54),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ),

              // Список тем
              _isLoading
                  ? Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: Colors.black87),
                ),
              )
                  : Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16.0),
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
    final hasImage = topic['image_path'] != null && topic['image_path'].toString().isNotEmpty;

    return Card(
      elevation: 6,
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          Navigator.push(
            context,
            PageRouteBuilder(
              settings: const RouteSettings(name: '/topic'),
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
        child: Stack(
          children: [
            if (hasImage)
              Container(
                height: 150,
                width: double.infinity,
                child: Image.asset(
                  topic['image_path'],
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[200],
                      child: Center(
                        child: Icon(
                          Icons.image_not_supported,
                          size: 50,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  },
                ),
              )
            else
              Container(
                height: 150,
                width: double.infinity,
                color: Colors.white.withOpacity(0.8),
                child: Center(
                  child: Icon(
                    Icons.menu_book,
                    size: 50,
                    color: Colors.black54,
                  ),
                ),
              ),


            Positioned(
              right: 10,
              bottom: 50,
              left: 200,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.5,
                ),
                child: Align(
                  alignment: Alignment.centerLeft, // Выравнивание текста по левому краю внутри контейнера
                  child: Text(
                    topic['title'],
                    style: GoogleFonts.montserrat(
                      textStyle: TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                        shadows: [
                          Shadow(
                            color: Colors.white,
                            offset: Offset(1, 1),
                            blurRadius: 10,
                          )
                        ],
                      ),
                    ),
                    textAlign: TextAlign.left, // Выравнивание текста по левому краю
                    maxLines: 3,
                    overflow: TextOverflow.fade,
                  ),
                ),
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
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }
}