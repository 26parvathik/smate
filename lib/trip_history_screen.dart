import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TripHistoryScreen extends StatelessWidget {
  const TripHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {

    final user = FirebaseAuth.instance.currentUser;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("trips")
              .where("userId", isEqualTo: user?.uid)
              .orderBy("timestamp", descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final trips = snapshot.data!.docs;

            if (trips.isEmpty) {
              return const Center(
                child: Text(
                  "No trips recorded",
                  style: TextStyle(color: Colors.white70),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    'Trip History',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: trips.length,
                    itemBuilder: (context, index) {
                      final trip = trips[index];

                      int harsh = trip.data().toString().contains("harshBraking")
                          ? trip["harshBraking"]
                          : 0;

                      int overspeed = trip.data().toString().contains("overspeed")
                          ? trip["overspeed"]
                          : 0;

                      double score = trip.data().toString().contains("score")
                          ? (trip["score"] as num).toDouble()
                          : 100;

                      double speedLimit = trip.data().toString().contains("speedLimit")
                          ? (trip["speedLimit"] as num).toDouble()
                          : 40;

                      return Card(
                        margin: const EdgeInsets.all(12),
                        color: const Color(0xFF1B1F34),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Score : ${score.toStringAsFixed(0)}",
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text("Harsh Braking : $harsh", style: const TextStyle(color: Colors.white70)),
                              Text("Overspeed : $overspeed", style: const TextStyle(color: Colors.white70)),
                              Text("Speed Limit : $speedLimit", style: const TextStyle(color: Colors.white70)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

