import 'package:flutter/material.dart';

import 'constants/app_config.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
  await NotificationService.init();
  if (kIsDevMode) {
    await NotificationService.scheduleDevModePrompts();
  } else {
    await NotificationService.scheduleHourlyPrompts();
  }
  runApp(const PlanPlusApp());
}

class PlanPlusApp extends StatelessWidget {
  const PlanPlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PlanPlus',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
