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

              Icon(
                Icons.directions_car,
                size: 120,
                color: Colors.greenAccent,
              ),

              SizedBox(height: 20),

              Text(
                "STEERMATE",
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                  color: Colors.greenAccent,
                ),
              ),

            ],
          ),

        ),

      ),

    );
  }
}