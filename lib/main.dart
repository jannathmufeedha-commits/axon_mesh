import 'package:flutter/material.dart';

void main() => runApp(const MaterialApp(home: SimpleApp()));

class SimpleApp extends StatelessWidget {
  const SimpleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Axon Test Build")),
      body: const Center(
        child: Text(
          "Build Successful!",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
        ),
      ),
    );
  }
}
