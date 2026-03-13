import 'package:flutter/material.dart';

import 'driving_screen.dart';
import 'trip_history_screen.dart';
import 'profile_screen.dart';
import 'checkered_background.dart';

class HomeScreen extends StatefulWidget {

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  int currentIndex = 0;

  final screens = [
    const DrivingScreen(),
    const TripHistoryScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      body: CheckeredBackground(
        child: screens[currentIndex],
      ),

      bottomNavigationBar: BottomNavigationBar(

        currentIndex: currentIndex,

        onTap: (index) {
          setState(() {
            currentIndex = index;
          });
        },

        items: const [

          BottomNavigationBarItem(
            icon: Icon(Icons.speed),
            label: "Drive",
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: "Trips",
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Profile",
          ),

        ],
      ),
    );
  }
}