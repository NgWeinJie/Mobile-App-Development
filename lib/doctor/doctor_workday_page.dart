import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DoctorWorkdayPage extends StatefulWidget {
  final Map<String, dynamic> weeklySessions;

  const DoctorWorkdayPage({Key? key, required this.weeklySessions}) : super(key: key);

  @override
  _DoctorWorkdayPageState createState() => _DoctorWorkdayPageState();
}

class _DoctorWorkdayPageState extends State<DoctorWorkdayPage> {
  late Map<String, List<Map<String, TextEditingController>>> _controllers;

  final daysOfWeek = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  @override
  void initState() {
    super.initState();

    _controllers = {};
    for (var day in daysOfWeek) {
      final sessions = widget.weeklySessions[day] ?? [];

      _controllers[day] = List.generate(sessions.length, (index) {
        return {
          'start': TextEditingController(text: sessions[index]['start'] ?? ''),
          'end': TextEditingController(text: sessions[index]['end'] ?? ''),
        };
      });
    }
  }

  Future<void> _saveToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Convert _controllers into a valid Firestore data format
    Map<String, dynamic> updatedSessions = {};

    for (var day in daysOfWeek) {
      updatedSessions[day] = _controllers[day]!
          .map((controllers) => {
        'start': controllers['start']!.text,
        'end': controllers['end']!.text,
      })
          .toList();
    }

    await FirebaseFirestore.instance.collection('doctors').doc(user.uid).update({
      'weeklySessions': updatedSessions,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Weekly sessions updated successfully!')),
    );
  }

  @override
  void dispose() {
    for (var day in daysOfWeek) {
      for (var session in _controllers[day]!) {
        session['start']?.dispose();
        session['end']?.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Schedule'),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveToFirestore,
            tooltip: 'Save',
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: daysOfWeek.length,
        itemBuilder: (context, index) {
          final day = daysOfWeek[index];
          final sessionControllers = _controllers[day]!;

          return Card(
            margin: const EdgeInsets.all(8),
            child: ExpansionTile(
              title: Text(
                day,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              children: sessionControllers.isNotEmpty
                  ? sessionControllers.asMap().entries.map((entry) {
                final i = entry.key;
                final session = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: session['start'],
                          decoration: const InputDecoration(labelText: 'Start Time'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: session['end'],
                          decoration: const InputDecoration(labelText: 'End Time'),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList()
                  : const [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No sessions available.'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
