import 'package:daily_sentences/composition/app_composition.dart';
import 'package:daily_sentences/presentation/home/home_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DailySentencesApp extends StatelessWidget {
  const DailySentencesApp({super.key});

  @override
  Widget build(BuildContext context) {
    final applicationName = context
        .watch<ApplicationConfiguration>()
        .applicationName;

    return MaterialApp(
      title: applicationName,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const HomePage(),
    );
  }
}
