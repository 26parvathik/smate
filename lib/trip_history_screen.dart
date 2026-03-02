import 'package:flutter/material.dart';

class TripHistoryScreen extends StatelessWidget {
  const TripHistoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Trip History")),
      body: const Center(
        child: Text("No trips recorded yet.",
            style: TextStyle(fontSize: 20, color: Colors.grey)),
      ),
    );
  }
}