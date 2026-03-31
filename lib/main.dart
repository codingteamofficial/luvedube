import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:luvedube/screens/home_screen.dart';

void main() async {    
  runApp(const MainApp());
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Luvedube',        
        theme: ThemeData(
          primaryColor: Colors.indigo,
          scaffoldBackgroundColor: const Color(0xFFF6F7F9), // very light grey
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            elevation: 1,
            iconTheme: IconThemeData(color: Colors.indigo),
            titleTextStyle: TextStyle(color: Colors.indigo, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Colors.indigo),
            ),
          ),
          
      ),
      home: const HomeScreen()     
    );
  }
}
