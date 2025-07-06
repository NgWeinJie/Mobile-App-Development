import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class PatientDetailsPage extends StatefulWidget {
  final String doctorId;
  final Map<String, dynamic> doctorData;
  final DateTime selectedDate;
  final String selectedTimeSlot;

  const PatientDetailsPage({
    super.key,
    required this.doctorId,
    required this.doctorData,
    required this.selectedDate,
    required this.selectedTimeSlot,
  });

  @override
  State<PatientDetailsPage> createState() => _PatientDetailsPageState();
}

class _PatientDetailsPageState extends State<PatientDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Controllers
  final TextEditingController _nricController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  // Form data
  String _selectedGender = 'Male';
  String _selectedDay = 'Day';
  String _selectedMonth = 'Month';
  String _selectedYear = 'Year';

  bool _isLoading = false;
  bool _hasPreviousAppointments = false;
  List<Map<String, dynamic>> _previousPatients = [];
  Map<String, dynamic>? _selectedPreviousPatient;

  @override
  void initState() {
    super.initState();
    _checkPreviousAppointments();
  }

  @override
  void dispose() {
    _nricController.dispose();
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _checkPreviousAppointments() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final querySnapshot = await _firestore
          .collection('appointments')
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        await _fetchPreviousPatients();
        setState(() {
          _hasPreviousAppointments = true;
        });
      } else {
        setState(() {
          _hasPreviousAppointments = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error checking previous appointments: $e');
    }
  }

  Future<void> _fetchPreviousPatients() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final querySnapshot = await _firestore
          .collection('appointments')
          .where('userId', isEqualTo: user.uid)
          .get();

      final patients = <Map<String, dynamic>>[];
      final seenNrics = <String>{};

      for (var doc in querySnapshot.docs) {
        final patientData = doc.data()['patientDetails'] as Map<String, dynamic>?;
        if (patientData != null) {
          final nric = patientData['nric'] as String? ?? '';
          if (!seenNrics.contains(nric)) {
            seenNrics.add(nric);
            patients.add(patientData);
          }
        }
      }

      setState(() {
        _previousPatients = patients;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error fetching previous patients: $e');
    }
  }

  void _selectPreviousPatient(Map<String, dynamic> patient) {
    setState(() {
      _selectedPreviousPatient = patient;

      // Fill the form with previous patient data
      _nricController.text = patient['nric'] ?? '';
      _nameController.text = patient['name'] ?? '';
      _mobileController.text = patient['mobile'] ?? '';
      _emailController.text = patient['email'] ?? '';
      _selectedGender = patient['gender'] ?? 'Male';

      // Parse birth date
      if (patient['birthDate'] != null) {
        final parts = patient['birthDate'].toString().split('-');
        if (parts.length == 3) {
          _selectedYear = parts[0];
          _selectedMonth = _getMonths()[int.parse(parts[1])];
          _selectedDay = parts[2];
        }
      }
    });
  }

  List<String> _getDays() {
    return ['Day'] + List.generate(31, (index) => (index + 1).toString().padLeft(2, '0'));
  }

  List<String> _getMonths() {
    return ['Month'] + [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
  }

  List<String> _getYears() {
    final currentYear = DateTime.now().year;
    return ['Year'] + List.generate(100, (index) => (currentYear - index).toString());
  }

  bool _isFormValid() {
    return _nricController.text.isNotEmpty &&
        _nameController.text.isNotEmpty &&
        _mobileController.text.isNotEmpty &&
        _emailController.text.isNotEmpty &&
        _selectedDay != 'Day' &&
        _selectedMonth != 'Month' &&
        _selectedYear != 'Year';
  }

  Future<void> _saveAppointment() async {
    if (!_formKey.currentState!.validate() || !_isFormValid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to make an appointment'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Create birth date
      final monthNumber = _getMonths().indexOf(_selectedMonth).toString().padLeft(2, '0');
      final birthDate = '$_selectedYear-$monthNumber-$_selectedDay';

      // Create appointment data
      final appointmentData = {
        'userId': user.uid,
        'doctorId': widget.doctorId,
        'doctorName': widget.doctorData['name'],
        'doctorSpecialization': widget.doctorData['specialization'],
        'doctorHospital': widget.doctorData['hospital'],
        'doctorimg': widget.doctorData['imageUrl'],
        'appointmentDate': DateFormat('yyyy-MM-dd').format(widget.selectedDate),
        'timeSlot': widget.selectedTimeSlot,
        'status': 'pending',
        'patientDetails': {
          'nric': _nricController.text.trim(),
          'name': _nameController.text.trim(),
          'birthDate': birthDate,
          'gender': _selectedGender,
          'mobile': _mobileController.text.trim(),
          'email': _emailController.text.trim(),
        },
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('appointments').add(appointmentData);

      setState(() {
        _isLoading = false;
      });

      // Show success dialog
      _showSuccessDialog();

    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      print('Error saving appointment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error booking appointment. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    size: 40,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                const Text(
                  'Appointment Successful!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Subtitle
                const Text(
                  'Your Appointment is Confirmed',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 24),

                // Details Container
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow('Doctor', widget.doctorData['name'] ?? 'Unknown'),
                      const SizedBox(height: 16),
                      _buildDetailRow('Specialization', widget.doctorData['specialization'] ?? 'General'),
                      const SizedBox(height: 16),
                      _buildDetailRow('Hospital', widget.doctorData['hospital'] ?? 'Unknown'),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailRow('Date', '${widget.selectedDate.day}/${widget.selectedDate.month}/${widget.selectedDate.year}'),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _buildDetailRow('Time', widget.selectedTimeSlot),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildDetailRow('Patient', _nameController.text),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Done Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/userHome',
                            (Route<dynamic> route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
      ],
    );
  }
  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
    required String hint,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(hint),
          onChanged: onChanged,
          items: items.map<DropdownMenuItem<String>>((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                style: TextStyle(
                  color: item == hint ? Colors.grey : Colors.black87,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey.shade500),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.blue),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildPreviousPatientsSection() {
    if (!_hasPreviousAppointments || _previousPatients.isEmpty) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Have you made an appointment before?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Select Patient Details'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _previousPatients.length,
                    itemBuilder: (context, index) {
                      final patient = _previousPatients[index];
                      return ListTile(
                        title: Text(patient['name'] ?? ''),
                        subtitle: Text('NRIC: ${patient['nric'] ?? ''}'),
                        onTap: () {
                          _selectPreviousPatient(patient);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Row(
              children: [
                const Icon(Icons.history, color: Colors.blue),
                const SizedBox(width: 12),
                const Text(
                  'Select from previous patient details',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Icon(Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.blue.shade400),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF5FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEAF5FF),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_ios, color: Colors.black),
        ),
        title: const Text(
          'Patient Details',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Previous patients section (only shows if has previous appointments)
                      _buildPreviousPatientsSection(),

                      // NRIC/Passport No
                      const Text(
                        'NRIC/Passport No',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _nricController,
                        hintText: '023456-07-0001919',
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter NRIC/Passport number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Patient's Name
                      const Text(
                        'Patient\'s Name',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _nameController,
                        hintText: 'Aisyah binti Mohamed',
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter patient name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Age
                      const Text(
                        'Age',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdown(
                              value: _selectedDay,
                              items: _getDays(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedDay = value ?? 'Day';
                                });
                              },
                              hint: 'Day',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDropdown(
                              value: _selectedMonth,
                              items: _getMonths(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedMonth = value ?? 'Month';
                                });
                              },
                              hint: 'Month',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDropdown(
                              value: _selectedYear,
                              items: _getYears(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedYear = value ?? 'Year';
                                });
                              },
                              hint: 'Year',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Gender
                      const Text(
                        'Gender',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Radio<String>(
                                  value: 'Male',
                                  groupValue: _selectedGender,
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedGender = value ?? 'Male';
                                    });
                                  },
                                  activeColor: Colors.blue,
                                ),
                                const Text('Male'),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Row(
                              children: [
                                Radio<String>(
                                  value: 'Female',
                                  groupValue: _selectedGender,
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedGender = value ?? 'Female';
                                    });
                                  },
                                  activeColor: Colors.blue,
                                ),
                                const Text('Female'),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Row(
                              children: [
                                Radio<String>(
                                  value: 'Others',
                                  groupValue: _selectedGender,
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedGender = value ?? 'Others';
                                    });
                                  },
                                  activeColor: Colors.blue,
                                ),
                                const Text('Others'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Mobile Number
                      const Text(
                        'Mobile Number',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _mobileController,
                        hintText: '+60-0000000000',
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter mobile number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Email
                      const Text(
                        'Email',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _emailController,
                        hintText: 'tomatomaumar1@gmail.com',
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter email address';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Done Button
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveAppointment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : const Text(
                  'Done',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}