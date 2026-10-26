import 'package:flutter/material.dart';

import '../features/system/connection_page.dart';

class VieGymApp extends StatelessWidget {
  const VieGymApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VieGym',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
      home: const ConnectionPage(),
    );
  }
}
