import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'login_screen.dart';
import 'checkered_background.dart';

class ProfileScreen extends StatefulWidget {

  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {

  String name = "";
  String email = "";
  String phone = "";
  String vehicle = "";

  @override
  void initState() {
    super.initState();
    loadUser();
  }

  Future<void> loadUser() async {

    final user = FirebaseAuth.instance.currentUser;

    final doc = await FirebaseFirestore.instance
        .collection("users")
        .doc(user!.uid)
        .get();

    setState(() {
      name = doc["name"];
      email = doc["email"];
      phone = doc["phone"];
      vehicle = doc["vehicle"];
    });
  }

  Future<void> logout() async {

    await FirebaseAuth.instance.signOut();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {

    return CheckeredBackground(

      child: Center(

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [

            const CircleAvatar(
              radius: 50,
              child: Icon(Icons.person, size: 40),
            ),

            const SizedBox(height: 20),

            Text(name, style: const TextStyle(fontSize: 22)),
            Text(email),
            Text(phone),
            Text(vehicle),

            const SizedBox(height: 30),

            ElevatedButton.icon(
              onPressed: logout,
              icon: const Icon(Icons.logout),
              label: const Text("Logout"),
            )

          ],
        ),
      ),
    );
  }
}