import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme/app_theme.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const XiomiApp());
}

class XiomiApp extends StatelessWidget {
  const XiomiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Xiomi',
      debugShowCheckedModeBanner: false,
      theme: XiomiTheme.light(),
      home: const SplashScreen(),
    );
  }
}
