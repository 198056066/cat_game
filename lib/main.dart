import 'package:flutter/material.dart';

import 'screens/game_screen.dart';

void main() {
  runApp(const CatGameApp());
}

class CatGameApp extends StatelessWidget {
  const CatGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cat Game',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFF2B366),
          secondary: Color(0xFFE08A3C),
          background: Color(0xFFF8E8C8),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8E8C8),
        useMaterial3: true,
      ),
      home: const GameScreen(),
    );
  }
}
