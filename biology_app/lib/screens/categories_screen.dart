import 'package:flutter/material.dart';
import 'dart:ui';
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
  CategoriesScreenState createState() => CategoriesScreenState();
}

class CategoriesScreenState extends State<CategoriesScreen> {
  List<Map<String, dynamic>> _topics = [];
  List<Map<String, dynamic>> _filteredTopics = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  String _getBackgroundImage() {
    switch (widget.chapterId) {
      case 1: return "assets/images/backgroundfirstchapter.jpg";
      case 2: return "assets/images/backgroundsecondchapter.jpg";
      case 3: return "assets/images/backgroundthirdchapter.jpg";
      case 4: return "assets/images/backgroundfourthchapter.jpg";
      default: return "assets/images/backgrounddefault.jpg";
    }
  }

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
          .where((topic) => topic['title'].toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide > 600;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(_getBackgroundImage()),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Column(
            children: [
              Padding(
                padding: EdgeInsets.only(
                  top: isTablet ? 80 : 60,
                  left: 16,
                  right: 16,
                  bottom: 16,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back,
                        color: Colors.black,
                        size: isTablet ? 32 : 28,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.chapterTitle,
                        style: TextStyle(
                          fontSize: isTablet ? 28 : 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          height: 1.0,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(width: isTablet ? 48 : 40),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  isTablet ? 24 : 16,
                ),
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
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: isTablet ? 18 : null,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Поиск по темам...',
                      hintStyle: TextStyle(
                        color: Colors.black54,
                        fontSize: isTablet ? 18 : null,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.black54,
                        size: isTablet ? 28 : null,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: isTablet ? 16 : 12,
                      ),
                    ),
                  ),
                ),
              ),
              _isLoading
                  ? Expanded(
                child: Center(
                  child: CircularProgressIndicator(
                    color: Colors.black87,
                    strokeWidth: isTablet ? 3 : null,
                  ),
                ),
              )
                  : Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.all(isTablet ? 24.0 : 16.0),
                  itemCount: _filteredTopics.length,
                  itemBuilder: (context, index) {
                    final topic = _filteredTopics[index];
                    return Stack(
                      children: [
                        _buildTopicCard(context, topic, isTablet),
                        Positioned(
                          top: isTablet ? 16 : 10,
                          right: isTablet ? 16 : 10,
                          child: _buildTestIndicator(topic['id'], isTablet),
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

  Widget _buildTopicCard(BuildContext context, Map<String, dynamic> topic, bool isTablet) {
    final hasImage = topic['image_path'] != null && topic['image_path'].toString().isNotEmpty;

    // Для телефонов - оставляем старую версию (текст поверх картинки)
    if (!isTablet) {
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
                  chapterId: widget.chapterId,
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
          child: SizedBox(
            height: 145,
            child: Stack(
              children: [
                if (hasImage)
                  Positioned.fill(
                    child: Image.asset(
                      topic['image_path'],
                      fit: BoxFit.fitWidth,
                      width: double.infinity,
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
                  Positioned.fill(
                    child: Container(
                      color: Colors.white.withOpacity(0.8),
                      child: Center(
                        child: Icon(
                          Icons.menu_book,
                          size: 50,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 16,
                  top: 0,
                  bottom: 0,
                  width: MediaQuery.of(context).size.width * 0.5,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        topic['title'],
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                          height: 1.0,
                          shadows: [
                            Shadow(
                              color: Colors.white,
                              offset: Offset(1, 1),
                              blurRadius: 10,
                            )
                          ],
                        ),
                        textAlign: TextAlign.left,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
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

    // Для планшетов - новая версия (картинка и текст в ряд)
    return Card(
      elevation: 6,
      margin: const EdgeInsets.only(bottom: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () {
          Navigator.push(
            context,
            PageRouteBuilder(
              settings: const RouteSettings(name: '/topic'),
              pageBuilder: (context, animation, secondaryAnimation) => TopicScreen(
                topicTitle: topic['title'],
                topicId: topic['id'],
                chapterImage: widget.chapterImage,
                chapterId: widget.chapterId,
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
        child: SizedBox(
          height: 200,
          child: Row(
            children: [
              if (hasImage)
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage(topic['image_path']),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Image.asset(
                      topic['image_path'],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: Center(
                            child: Icon(
                              Icons.image_not_supported,
                              size: 60,
                              color: Colors.grey,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  color: Colors.white.withOpacity(0.85),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        topic['title'],
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          height: 1.2,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Нажмите для изучения',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTestIndicator(int topicId, bool isTablet) {
    return FutureBuilder<double?>(
      future: TestProgressService.getTestScore(topicId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildIndicator(Colors.red, isTablet);
        }

        double score = snapshot.data!;
        if (score >= 90) {
          return _buildIndicator(Colors.green, isTablet);
        } else {
          return _buildIndicator(Colors.orange, isTablet);
        }
      },
    );
  }

  Widget _buildIndicator(Color color, bool isTablet) {
    return Container(
      width: isTablet ? 26 : 20,
      height: isTablet ? 26 : 20,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: isTablet ? 3 : 2,
        ),
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