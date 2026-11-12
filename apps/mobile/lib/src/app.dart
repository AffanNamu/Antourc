import 'package:flutter/material.dart';

import 'features/home/home_page.dart';

class AssistLinkApp extends StatelessWidget {
  const AssistLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF4C8DFF);
    return MaterialApp(
      title: 'AssistLink',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
          surface: const Color(0xFF10141D),
        ),
        scaffoldBackgroundColor: const Color(0xFF0A0D14),
        cardTheme: CardTheme(
          color: const Color(0xFF141B27),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF263246)),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}
