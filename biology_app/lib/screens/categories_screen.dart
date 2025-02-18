import 'package:flutter/material.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Категории'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildCategoryCard(
            'Тема',
            'assets/images/bio.jpg', 
          ),
          const SizedBox(height: 16),
          _buildCategoryCard(
            'Тема',
            'assets/images/bio.jpg',
          ),
          const SizedBox(height: 16),
          _buildCategoryCard(
            'Тема',
            'assets/images/bio.jpg',
          ),
          const SizedBox(height: 16),
          _buildCategoryCard(
            'Тема',
            'assets/images/bio.jpg',
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(String title, String imageUrl) {
    return Card(
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          // Здесь будет переход к вопросам категории
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 200,
              child: Image.asset(
                imageUrl,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 