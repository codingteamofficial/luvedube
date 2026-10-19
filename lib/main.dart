import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:luvedube/screens/home_screen.dart';
import 'package:luvedube/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // must come BEFORE runApp
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Tech.bg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const MainApp());
  unawaited(MobileAds.instance.initialize()); // don't block first frame
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LuveDuve',
      debugShowCheckedModeBanner: false,
      theme: Tech.theme(),
      home: const HomeScreen(),
    );
  }
}