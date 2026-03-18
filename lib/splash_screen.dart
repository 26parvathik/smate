import 'dart:async';
import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'checkered_background.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();

    Timer(const Duration(seconds: 2), () {

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
      );

    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      body: CheckeredBackground(

        child: Center(

          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,

            children: const [

              Text(
                "SteerMate",
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 3,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.white,
                      blurRadius: 20,
                    ),
                    Shadow(
                      color: Colors.blueAccent,
                      blurRadius: 30,
                    ),
                    Shadow(
                      color: Colors.lightBlueAccent,
                      blurRadius: 50,
                    ),
                  ],
                ),
              ),

            ],
          ),

        ),

      ),

    );
  }
}