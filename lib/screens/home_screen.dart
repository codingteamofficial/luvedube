import 'dart:async';

import 'package:flutter/material.dart';
import 'package:luvedube/screens/write_song_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {

  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();

    // Navigate after 3 seconds
    Timer(const Duration(seconds: 3), (){
      Navigator.push(context, MaterialPageRoute(builder: (context) => const WriteASongPage(),));
    });

  }



  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    //const primaryColor = Color(0xFF202124);
    const secondaryColor = Color(0xFF5F6368);

    return Scaffold(
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,  // Center vertically
              crossAxisAlignment: CrossAxisAlignment.center, // Center horizontally
              children: [

                /// LOGO
                Image.asset(
                  'assets/icons/Luvedube.png',
                  height: 180,
                ),

                const SizedBox(height: 30),

                /// APP NAME
                Text(
                  "LuveDuve",
                  style:TextStyle(
                    fontFamily: 'sans-serif', // Ya ise khali chhod dein
                    fontSize: 34,
                    fontWeight: FontWeight.w600, // Semi-bold
                    color: secondaryColor,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }
}

