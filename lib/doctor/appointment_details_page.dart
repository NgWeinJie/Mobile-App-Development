import 'package:flutter/material.dart';

class AppointmentDetailsPage extends StatelessWidget {
  final Map<String, dynamic> appointmentData;

  const AppointmentDetailsPage({super.key, required this.appointmentData});

  @override
  Widget build(BuildContext context) {
    final patient = appointmentData['patientDetails'] ?? {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointment Details'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            const Text(
              'Doctor Info',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Name: ${appointmentData['doctorName'] ?? 'N/A'}'),
            Text('Hospital: ${appointmentData['doctorHospital'] ?? 'N/A'}'),
            Text('Specialization: ${appointmentData['doctorSpecialization'] ?? 'N/A'}'),
            const SizedBox(height: 16),

            const Text(
              'Patient Info',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Name: ${patient['name'] ?? 'N/A'}'),
            Text('Email: ${patient['email'] ?? 'N/A'}'),
            Text('Mobile: ${patient['mobile'] ?? 'N/A'}'),
            Text('Gender: ${patient['gender'] ?? 'N/A'}'),
            Text('NRIC: ${patient['nric'] ?? 'N/A'}'),
            const SizedBox(height: 16),

            const Text(
              'Appointment Info',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Date: ${appointmentData['appointmentDate'] ?? 'N/A'}'),
            Text('Time Slot: ${appointmentData['timeSlot'] ?? 'N/A'}'),
            Text('Status: ${appointmentData['status'] ?? 'N/A'}'),
            const SizedBox(height: 16),

            if (appointmentData['createdAt'] != null)
              Text(
                'Created At: ${appointmentData['createdAt'].toDate().toLocal()}',
                style: const TextStyle(color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
}
