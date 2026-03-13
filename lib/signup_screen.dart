import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'checkered_background.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final vehicleController = TextEditingController();
  final passwordController = TextEditingController();

  Future<void> signup() async {

    try {

      UserCredential user =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(

        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.user!.uid)
          .set({

        "name": nameController.text,
        "email": emailController.text,
        "phone": phoneController.text,
        "vehicle": vehicleController.text,

      });

      Navigator.pop(context);

    } on FirebaseAuthException catch (e) {

      String message = "Signup failed";

      if (e.code == "email-already-in-use") {
        message = "Email already registered. Please login.";
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {

    return CheckeredBackground(

      child: SingleChildScrollView(

        padding: const EdgeInsets.all(30),

        child: Column(

          children: [

            const SizedBox(height: 40),

            const Text(
              "Create Account",
              style: TextStyle(fontSize: 30),
            ),

            const SizedBox(height: 40),

            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Name"),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: "Phone"),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: vehicleController,
              decoration: const InputDecoration(labelText: "Vehicle"),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password"),
            ),

            const SizedBox(height: 40),

            ElevatedButton(
              onPressed: signup,
              child: const Text("Create Account"),
            ),

          ],
        ),
      ),
    );
  }
}