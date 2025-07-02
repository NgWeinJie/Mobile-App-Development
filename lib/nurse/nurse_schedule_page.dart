import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class NurseSchedulePage extends StatefulWidget {
  const NurseSchedulePage({super.key});

  @override
  State<NurseSchedulePage> createState() => _NurseSchedulePageState();
}

class _NurseSchedulePageState extends State<NurseSchedulePage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<DocumentSnapshot> _appointments = [];
  final String _nurseId = FirebaseAuth.instance.currentUser!.uid;
  Map<DateTime, List<dynamic>> _events = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchAppointmentsForDay(_selectedDay!);
    _fetchMonthlyAppointments(_focusedDay);
  }

  Future<void> _fetchAppointmentsForDay(DateTime date) async {
    final formattedDate = DateFormat('yyyy-MM-dd').format(date);
    final now = DateTime.now();

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('booking')
          .where('nurseId', isEqualTo: _nurseId)
          .where('bookingDate', isEqualTo: formattedDate)
          .orderBy('timeSlot')
          .get();

      List<DocumentSnapshot> updatedAppointments = [];

      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final bookingDateStr = data['bookingDate'];
        final timeSlot = data['timeSlot'];
        final status = data['status'];

        if (bookingDateStr != null &&
            timeSlot != null &&
            status != 'Completed') {
          try {
            final appointmentDateTime = DateFormat('yyyy-MM-dd HH:mm')
                .parse('$bookingDateStr ${timeSlot.trim()}');

            if (appointmentDateTime.isBefore(now)) {
              await doc.reference.update({'status': 'Completed'});
              data['status'] = 'Completed';
            }
          } catch (e) {
            debugPrint('Error parsing timeSlot: $e');
          }
        }

        updatedAppointments.add(doc);
      }

      setState(() {
        _appointments = updatedAppointments;
      });
    } catch (e) {
      debugPrint('Error fetching appointments: $e');
      setState(() {
        _appointments = [];
      });
    }
  }

  Future<void> _fetchMonthlyAppointments(DateTime month) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('booking')
          .where('nurseId', isEqualTo: _nurseId)
          .get();

      final allAppointments = querySnapshot.docs;

      Map<DateTime, List<dynamic>> events = {};

      for (var doc in allAppointments) {
        final data = doc.data();
        final dateStr = data['bookingDate'] as String?;
        if (dateStr != null) {
          final date = DateTime.parse(dateStr);
          if (date.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
              date.isBefore(endOfMonth.add(const Duration(days: 1)))) {
            final eventDay = DateTime(date.year, date.month, date.day);
            events.putIfAbsent(eventDay, () => []).add(data);
          }
        }
      }

      setState(() {
        _events = events;
      });
    } catch (e) {
      debugPrint("Error fetching monthly appointments: $e");
    }
  }

  void _showAppointmentDetailsDialog(Map<String, dynamic> data) {
    final patient = data['patientDetails'] ?? {};

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Booking Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nurse Info', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Name: ${data['nurseName'] ?? 'N/A'}'),
              Text('Hospital: ${data['nurseHospital'] ?? 'N/A'}'),
              Text('Specialization: ${data['nurseSpecialization'] ?? 'N/A'}'),
              const SizedBox(height: 12),
              const Text('Patient Info', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Name: ${patient['name'] ?? 'N/A'}'),
              Text('Email: ${patient['email'] ?? 'N/A'}'),
              Text('Mobile: ${patient['mobile'] ?? 'N/A'}'),
              Text('Gender: ${patient['gender'] ?? 'N/A'}'),
              Text('Address: ${patient['address'] ?? 'N/A'}'),
              const SizedBox(height: 12),
              const Text('Booking Info', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Date: ${data['bookingDate'] ?? 'N/A'}'),
              Text('Time Slot: ${data['timeSlot'] ?? 'N/A'}'),
              Text('Status: ${data['status'] ?? 'N/A'}'),
              if (data['createdAt'] != null)
                Text('Created At: ${data['createdAt'].toDate().toLocal()}',
                    style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Close'),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formattedSelectedDate = DateFormat('yyyy-MM-dd').format(_selectedDay!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Schedule'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
              _fetchAppointmentsForDay(selectedDay);
              _fetchMonthlyAppointments(focusedDay);
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
              _fetchMonthlyAppointments(focusedDay);
            },
            eventLoader: (day) {
              return _events[DateTime(day.year, day.month, day.day)] ?? [];
            },
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isNotEmpty) {
                  return Positioned(
                    bottom: 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${events.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            calendarStyle: const CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.teal,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              'Bookings on $formattedSelectedDate',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: _appointments.isEmpty
                ? const Center(child: Text('No bookings for this day.'))
                : ListView.builder(
              itemCount: _appointments.length,
              itemBuilder: (context, index) {
                final data = _appointments[index].data() as Map<String, dynamic>;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: const Icon(Icons.access_time),
                    title: Text('Time: ${data['timeSlot']}'),
                    subtitle: Text('Status: ${data['status']}'),
                    onTap: () => _showAppointmentDetailsDialog(data),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
