import 'package:flutter/material.dart';

/// The root widget of the Legal Case Diary application.
/// Task 01: Placeholder MaterialApp for architecture scaffolding.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Legal Case Diary',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const Scaffold(
        body: Center(
          child: Text('Legal Case Diary — Offline First'),
        ),
      ),
    );
  }
}
