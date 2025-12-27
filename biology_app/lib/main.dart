import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'database.dart';
import 'screens/chapters_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:io';
import 'package:yandex_mobileads/mobile_ads.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Инициализация Yandex Mobile Ads SDK
    MobileAds.initialize();
    
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    await DBProvider.db.importFromDatabaseFile();
    runApp(const MainApp());
  } catch (e) {
    print('Ошибка при запуске: $e');
  }
}

class AppTheme {
  static String getChapterBackground(chapterId) {
    switch (chapterId) {
      case 1: return "assets/images/backgroundfirstchapter.webp";
      case 2: return "assets/images/backgroundsecondchapter.webp";
      case 3: return "assets/images/backgroundthirdchapter.webp";
      case 4: return "assets/images/backgroundfourthchapter.webp";
      default: return "assets/images/backgroundfirstchapter.webp";
    }
  }

  static BoxDecoration chapterBackgroundDecoration(int chapterId) {
    return BoxDecoration(
      image: DecorationImage(
        image: AssetImage(getChapterBackground(chapterId)),
        fit: BoxFit.cover,
      ),
    );
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        textTheme: GoogleFonts.montserratTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      home: const StartScreen(),
    );
  }
}

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  late VideoPlayerController _videoController;
  bool _showMainContent = false;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    _videoController = VideoPlayerController.asset('assets/videos/intro.mp4')
      ..setLooping(false);

    try {
      await _videoController.initialize();
      if (mounted) {
        setState(() => _isVideoInitialized = true);
        _videoController.play();

        _videoController.addListener(() {
          if (_videoController.value.position >=
              _videoController.value.duration) {
            _showMainInterface();
          }
        });
      }
    } catch (e) {
      print('Ошибка загрузки видео: $e');
      if (mounted) _showMainInterface();
    }
  }

  void _showMainInterface() {
    if (!_showMainContent && mounted) {
      setState(() => _showMainContent = true);
    }
  }

  void _skipVideo() {
    if (_isVideoInitialized) {
      _videoController.pause();
    }
    _showMainInterface();
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  Future<void> _openTelegram() async {
    const url = 'https://t.me/waytomedicine';
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      print('Ошибка открытия Telegram: $e');
    }
  }

  Route _createRoute() {
    return PageRouteBuilder(
      pageBuilder: (context, animation,
          secondaryAnimation) => const ChaptersScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.ease;
        var tween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
    );
  }

  Future<void> _showDocumentChoice() async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Выберите документ', textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text(
                    'Политика обработки данных', textAlign: TextAlign.center),
                onTap: () {
                  Navigator.pop(context);
                  _openDocument('assets/documents/politic.pdf');
                },
              ),
              ListTile(
                title: const Text('Положение об обработке персональных данных',
                    textAlign: TextAlign.center),
                onTap: () {
                  Navigator.pop(context);
                  _openDocument('assets/documents/processing_pd.pdf');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openDocument(String assetPath) async {
    try {
      final file = await _getLocalFile(assetPath);

      if (!await file.exists()) {
        _showError('Файл не найден');
        return;
      }

      final result = await OpenFile.open(file.path);

      if (result.type != ResultType.done) {
        _showError('Не удалось открыть файл: ${result.message}');
      }
    } catch (e) {
      _showError('Ошибка при открытии файла: ${e.toString()}');
    }
  }

  Future<File> _getLocalFile(String assetPath) async {
    try {
      final byteData = await rootBundle.load(assetPath);
      final tempDir = await getTemporaryDirectory();
      final fileName = assetPath
          .split('/')
          .last;
      final tempPath = '${tempDir.path}/$fileName';
      final file = File(tempPath);
      await file.writeAsBytes(byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      ));
      return file;
    } catch (e) {
      print('Ошибка при создании временного файла: $e');
      throw Exception('Не удалось создать временный файл');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, textAlign: TextAlign.center)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery
        .of(context)
        .size
        .height;
    final screenWidth = MediaQuery
        .of(context)
        .size
        .width;
    final isSmallScreen = screenHeight < 600 || screenWidth < 350;

    return Scaffold(
      body: Stack(
        children: [
          if (!_showMainContent && _isVideoInitialized)
            GestureDetector(
              onTap: _skipVideo,
              child: SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _videoController.value.size.width,
                    height: _videoController.value.size.height,
                    child: VideoPlayer(_videoController),
                  ),
                ),
              ),
            ),

          if (!_showMainContent && !_isVideoInitialized)
            const ColoredBox(color: Colors.black),

          if (_showMainContent)
            AnimatedOpacity(
              opacity: _showMainContent ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              child: Container(
                decoration: AppTheme.chapterBackgroundDecoration(1),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: SafeArea(
                          child: Padding(
                            padding: EdgeInsets.all(
                                isSmallScreen ? 12.0 : 16.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Image.asset(
                                    'assets/images/icon/logobio.png',
                                    height: isSmallScreen ? 100 : 160,
                                    width: isSmallScreen ? 100 : 150,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                SizedBox(height: isSmallScreen ? 10 : 20),
                                Text(
                                  'Дорогой друг!',
                                  style: GoogleFonts.montserrat(
                                    textStyle: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: isSmallScreen ? 18 : 24,
                                      color: Colors.black,
                                    ),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: isSmallScreen ? 8 : 12),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: isSmallScreen ? 10 : 20),
                                  child: Text(
                                    'Это приложение поможет подготовиться к ЕГЭ, ОГЭ и другим экзаменам по биологии, предлагая задания разных форматов для развития биологического мышления и выявления слабых тем',
                                    textAlign: TextAlign.justify,
                                    style: GoogleFonts.montserrat(
                                      textStyle: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        fontSize: isSmallScreen ? 12 : 16,
                                        color: Colors.black,
                                        letterSpacing: -0.2,
                                        wordSpacing: 0.5,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: isSmallScreen ? 8 : 12),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: isSmallScreen ? 10 : 20),
                                  child: Text(
                                    'Загляни в наш ТГ-Канал для полезной информации!',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.montserrat(
                                      textStyle: TextStyle(
                                        fontSize: isSmallScreen ? 12 : 16,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: isSmallScreen ? 8 : 12),
                                SizedBox(
                                  width: isSmallScreen ? 180 : 220,
                                  height: isSmallScreen ? 36 : 44,
                                  child: ElevatedButton(
                                    onPressed: _openTelegram,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF42A5F5),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment
                                          .center,
                                      children: [
                                        Icon(Icons.send, color: Colors.white,
                                            size: isSmallScreen ? 16 : 20),
                                        SizedBox(width: 6),
                                        Text(
                                          'Telegram',
                                          style: GoogleFonts.montserrat(
                                            textStyle: TextStyle(
                                              fontSize: isSmallScreen ? 14 : 18,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(height: isSmallScreen ? 8 : 12),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: isSmallScreen ? 10 : 20),
                                  child: Text(
                                    'У тебя всё получится! Вперёд!',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.montserrat(
                                      textStyle: TextStyle(
                                        fontSize: isSmallScreen ? 12 : 16,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: isSmallScreen ? 8 : 12),
                                SizedBox(
                                  width: isSmallScreen ? 180 : 220,
                                  height: isSmallScreen ? 36 : 44,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.pushReplacement(
                                          context, _createRoute());
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF42A5F5),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    child: Text(
                                      'Вперёд!',
                                      style: GoogleFonts.montserrat(
                                        textStyle: TextStyle(
                                          fontSize: isSmallScreen ? 14 : 18,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: isSmallScreen ? 8 : 12),
                                GestureDetector(
                                  onTap: _showDocumentChoice,
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Text(
                                      'Политика обработки и Положение об обработке персональных данных',
                                      style: GoogleFonts.montserrat(
                                        textStyle: TextStyle(
                                          fontSize: isSmallScreen ? 10 : 14,
                                          color: Colors.black,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}