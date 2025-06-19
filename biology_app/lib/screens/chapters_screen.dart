import 'package:flutter/material.dart';
import '../database.dart';
import 'categories_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:open_file/open_file.dart';
import 'package:clipboard/clipboard.dart';
import 'package:flutter/services.dart';

class ChaptersScreen extends StatefulWidget {
  const ChaptersScreen({super.key});

  @override
  State<ChaptersScreen> createState() => _ChaptersScreenState();
}

class _ChaptersScreenState extends State<ChaptersScreen> {
  List<Map<String, dynamic>> _chapters = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChapters();
  }

  Future<void> _loadChapters() async {
    try {
      final chapters = await DBProvider.db.getChapters();
      setState(() {
        _chapters = chapters;
        _isLoading = false;
      });
    } catch (e) {
      print('Ошибка при загрузке глав: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _launchEmail() async {
    final email = 'support@krommarketing.ru';
    final subject = 'Техподдержка приложения';
    final body = 'Здравствуйте, у меня возник вопрос:';

    // Вариант 1: Попробуем открыть Gmail через Intent (Android)
    if (Platform.isAndroid) {
      try {
        final gmailIntent = Uri(
          scheme: 'intent',
          host: 'com.google.android.gm',
          path: '/compose/mail',
          queryParameters: {
            'to': email,
            'subject': subject,
            'body': body,
          },
        ).toString();

        if (await canLaunchUrl(Uri.parse(gmailIntent))) {
          await launchUrl(Uri.parse(gmailIntent), mode: LaunchMode.externalApplication);
          return;
        }
      } catch (e) {
        print('Ошибка при открытии Gmail через Intent: $e');
      }
    }

    // Вариант 2: Стандартный mailto
    final mailtoUri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        'subject': subject,
        'body': body,
      },
    );

    if (await canLaunchUrl(mailtoUri)) {
      await launchUrl(mailtoUri, mode: LaunchMode.externalApplication);
      return;
    }

    // Вариант 3: Web-версия Gmail
    final gmailWebUri = Uri(
      scheme: 'https',
      host: 'mail.google.com',
      path: '/mail/u/0/',
      queryParameters: {
        'view': 'cm',
        'fs': '1',
        'to': email,
        'su': subject,
        'body': body,
      },
    );

    if (await canLaunchUrl(gmailWebUri)) {
      await launchUrl(gmailWebUri, mode: LaunchMode.externalApplication);
      return;
    }

    // Если ничего не сработало, предлагаем скопировать email
    await _showEmailCopyDialog(email, subject, body);
  }

  Future<void> _showEmailCopyDialog(String email, String subject, String body) async {
    final text = 'mailto:$email?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}';

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Почтовое приложение не найдено'),
        content: const Text('Скопируйте email и отправьте письмо вручную'),
        actions: [
          TextButton(
            child: const Text('Копировать email'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: email)); // Используем правильный импорт
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Email скопирован в буфер обмена')),
              );
            },
          ),
          TextButton(
            child: const Text('Копировать всё письмо'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text)); // Используем правильный импорт
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Данные письма скопированы')),
              );
            },
          ),
          TextButton(
            child: const Text('Закрыть'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Future<void> _showDocumentChoice() async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Выберите документ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Политика обработки данных'),
                onTap: () {
                  Navigator.pop(context);
                  _openDocument('assets/documents/politic.pdf');
                },
              ),
              ListTile(
                title: const Text('Положение об обработке персональных данных'),
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
      if (await file.exists()) {
        final result = await OpenFile.open(file.path);
        if (result != "done") { // В новых версиях "done" означает успешное открытие
          _showError('Не удалось открыть файл: $result');
        }
      } else {
        _showError('Файл не найден: ${file.path}');
      }
    } catch (e) {
      _showError('Ошибка при открытии файла: ${e.toString()}');
    }
  }

  Future<File> _getLocalFile(String assetPath) async {
    final byteData = await rootBundle.load(assetPath);
    final buffer = byteData.buffer;
    final tempDir = await getTemporaryDirectory();
    final tempPath = '${tempDir.path}/${assetPath.split('/').last}';
    return File(tempPath)..writeAsBytes(buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: Image.asset("assets/images/backgroundfirstchapter.jpg").image,
            fit: BoxFit.cover,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.black))
            : Column(
          children: [
            // Кнопки вверху экрана
            Padding(
              padding: const EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.mail_outline, color: Colors.black54),
                    onPressed: _launchEmail,
                    tooltip: 'Техподдержка',
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.description_outlined, color: Colors.black54),
                    onPressed: _showDocumentChoice,
                    tooltip: 'Документы',
                  ),
                ],
              ),
            ),
            // Основной контент
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Выберите главу',
                        style: GoogleFonts.montserrat(
                          textStyle: const TextStyle(
                            color: Colors.black,
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      ..._chapters.map((chapter) {
                        return Container(
                          width: MediaQuery.of(context).size.width * 0.8,
                          margin: const EdgeInsets.only(bottom: 16),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF42A5F5),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              elevation: 4,
                              minimumSize: const Size(double.infinity, 60),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  settings: const RouteSettings(name: '/categories'),
                                  pageBuilder: (context, animation, secondaryAnimation) => CategoriesScreen(
                                    chapterId: chapter['id'],
                                    chapterTitle: chapter['title'],
                                    chapterImage: chapter['image_path'],
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
                            child: Text(
                              '${chapter['title']}',
                              style: GoogleFonts.montserrat(
                                textStyle: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}