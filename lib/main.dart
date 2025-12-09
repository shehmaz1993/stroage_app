import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storage_app/features/screens/upload_screen.dart';
import 'package:storage_app/services/background_manager.dart';
import 'package:storage_app/utils/apps_global.dart';

import 'features/screens/dashboard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initializeWorkManager();
  runApp(ProviderScope(
    child: MyApp(), // Replace MyApp() with your actual root widget if different
  ),);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'File Transfer App',
      navigatorKey: navigatorKey,
      home: const DashboardScreen(),
    );
  }
}

