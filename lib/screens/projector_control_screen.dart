import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ProjectorControlScreen extends StatefulWidget {
  const ProjectorControlScreen({super.key});

  @override
  State<ProjectorControlScreen> createState() => _ProjectorControlScreenState();
}

class _ProjectorControlScreenState extends State<ProjectorControlScreen> {
  Future<void> connectToPC() async {
    final url = Uri.parse('http://192.168.1.100:5000/connect'); // Change to your PC endpoint
    try {
      final response = await http.post(url, body: {'action': 'connect'});
      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connected to PC!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect: \\${response.statusCode}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: \\${e.toString()}')),
      );
    }
  }

  Future<void> castToProjector() async {
    final url = Uri.parse('http://192.168.1.100:5000/cast'); // Change to your projector endpoint
    try {
      final response = await http.post(url, body: {'action': 'cast'});
      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Casting to projector started!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cast: \\${response.statusCode}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: \\${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Projector Control')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Control your slides with gestures.'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              connectToPC();
            },
            child: const Text('Connect to PC'),
          ),
          ElevatedButton(
            onPressed: () {
              castToProjector();
            },
            child: const Text('Cast to Projector'),
          ),
        ],
      ),
    );
  }
}
