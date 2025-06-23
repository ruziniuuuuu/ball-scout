import 'package:flutter/material.dart';

class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('足球新闻'),
      ),
      body: const Center(
        child: Text('新闻页面 - 开发中'),
      ),
    );
  }
} 