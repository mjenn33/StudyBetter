import 'package:flutter/material.dart';

/// Root widget of the StudyBetter app.
class StudyBetterApp extends StatelessWidget {
  const StudyBetterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StudyBetter',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: const Scaffold(body: Center(child: Text('StudyBetter'))),
    );
  }
}
