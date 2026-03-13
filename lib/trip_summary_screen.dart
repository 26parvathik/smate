import 'package:flutter/material.dart';

class TripSummaryScreen extends StatelessWidget {

  final double score;
  final int harshBrake;
  final int overspeed;
  final double speedLimit;

  const TripSummaryScreen({
    super.key,
    required this.score,
    required this.harshBrake,
    required this.overspeed,
    required this.speedLimit,
  });

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("Trip Summary"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [

            const SizedBox(height: 40),

            const Text(
              "Trip Completed",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 40),

            Text(
              "Driving Score",
              style: TextStyle(
                fontSize: 22,
                color: Colors.grey[600],
              ),
            ),

            const SizedBox(height: 10),

            Text(
              score.toStringAsFixed(0),
              style: const TextStyle(
                fontSize: 60,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),

            const SizedBox(height: 40),

            Card(
              child: ListTile(
                title: const Text("Harsh Braking Events"),
                trailing: Text(
                  harshBrake.toString(),
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),

            Card(
              child: ListTile(
                title: const Text("Overspeed Events"),
                trailing: Text(
                  overspeed.toString(),
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),

            Card(
              child: ListTile(
                title: const Text("Speed Limit Used"),
                trailing: Text(
                  "${speedLimit.toInt()} km/h",
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),

            const Spacer(),

            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Back to Dashboard"),
            ),

            const SizedBox(height: 20),

          ],
        ),
      ),
    );
  }
}

