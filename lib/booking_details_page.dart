import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'payment_page.dart';

class BookingDetailsPage extends StatefulWidget {
  final String doctorId;
  final Map<String, dynamic> doctorData;
  final DateTime selectedDate;
  final String selectedTimeSlot;
  final bool isHomeCare;

  const BookingDetailsPage({
    super.key,
    required this.doctorId,
    required this.doctorData,
    required this.selectedDate,
    required this.selectedTimeSlot,
    this.isHomeCare = false,
  });

  @override
  State<BookingDetailsPage> createState() => _BookingDetailsPageState();
}

class _BookingDetailsPageState extends State<BookingDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Controllers
  final TextEditingController _nricController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  // Address controllers for home care
  final TextEditingController _addressLine1Controller = TextEditingController();
  final TextEditingController _addressLine2Controller = TextEditingController();
  final TextEditingController _postcodeController = TextEditingController();

  // Form data
  String _selectedGender = 'Male';
  String _selectedDay = 'Day';
  String _selectedMonth = 'Month';
  String _selectedYear = 'Year';
  String _selectedArea = 'Select Area';

  bool _isLoading = false;
  bool _hasPreviousBookings = false;
  List<Map<String, dynamic>> _previousPatients = [];
  Map<String, dynamic>? _selectedPreviousPatient;

  // Penang areas
  final List<String> _penangAreas = [
    'Select Area',
    'Georgetown',
    'Jelutong',
    'Gelugor',
    'Sungai Ara',
    'Bayan Lepas',
    'Bayan Baru',
    'Tanjung Tokong',
    'Pulau Tikus',
    'Air Itam',
    'Farlim',
    'Paya Terubong',
    'Tanjung Bungah',
    'Batu Ferringhi',
    'Teluk Bahang',
    'Balik Pulau',
    'Butterworth',
    'Perai',
    'Bukit Mertajam',
    'Alma',
    'Seberang Jaya',
    'Seberang Perai',
    'Kepala Batas',
    'Tasek Gelugor',
    'Nibong Tebal',
    'Sungai Bakap',
    'Simpang Ampat',
    'Batu Kawan',
  ];

  @override
  void initState() {
    super.initState();
    _checkPreviousBookings();
  }

  @override
  void dispose() {
    _nricController.dispose();
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _postcodeController.dispose();
    super.dispose();
  }

  Future<void> _checkPreviousBookings() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Check booking collection first (priority for home care with address)
      final bookingsSnapshot = await _firestore
          .collection('booking')
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (bookingsSnapshot.docs.isNotEmpty) {
        await _fetchPreviousPatients();
        setState(() {
          _hasPreviousBookings = true;
        });
      } else {
        // Only check appointments if no bookings found
        final appointmentsSnapshot = await _firestore
            .collection('appointments')
            .where('userId', isEqualTo: user.uid)
            .limit(1)
            .get();

        if (appointmentsSnapshot.docs.isNotEmpty) {
          await _fetchPreviousPatients();
          setState(() {
            _hasPreviousBookings = true;
          });
        } else {
          setState(() {
            _hasPreviousBookings = false;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error checking previous bookings: $e');
    }
  }

  Future<void> _fetchPreviousPatients() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final patients = <Map<String, dynamic>>[];
      final seenNrics = <String>{};

      // Fetch from booking collection first (priority for address details)
      final bookingsSnapshot = await _firestore
          .collection('booking')
          .where('userId', isEqualTo: user.uid)
          .get();

      for (var doc in bookingsSnapshot.docs) {
        final patientData = doc.data()['patientDetails'] as Map<String, dynamic>?;
        if (patientData != null) {
          final nric = patientData['nric'] as String? ?? '';
          if (!seenNrics.contains(nric)) {
            seenNrics.add(nric);
            patients.add(patientData);
          }
        }
      }

      // Only fetch from appointments if no booking data found for home care
      if (patients.isEmpty || !widget.isHomeCare) {
        final appointmentsSnapshot = await _firestore
            .collection('appointments')
            .where('userId', isEqualTo: user.uid)
            .get();

        for (var doc in appointmentsSnapshot.docs) {
          final patientData = doc.data()['patientDetails'] as Map<String, dynamic>?;
          if (patientData != null) {
            final nric = patientData['nric'] as String? ?? '';
            if (!seenNrics.contains(nric)) {
              seenNrics.add(nric);
              patients.add(patientData);
            }
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

      // Fill address details for home care
      if (widget.isHomeCare) {
        _addressLine1Controller.text = patient['addressLine1'] ?? '';
        _addressLine2Controller.text = patient['addressLine2'] ?? '';
        _postcodeController.text = patient['postcode'] ?? '';
        _selectedArea = patient['area'] ?? 'Select Area';

        // Fallback to old address field if new fields are empty
        if (_addressLine1Controller.text.isEmpty && patient['address'] != null) {
          _addressLine1Controller.text = patient['address'];
        }
      }

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
    bool basicValid = _nricController.text.isNotEmpty &&
        _nameController.text.isNotEmpty &&
        _mobileController.text.isNotEmpty &&
        _emailController.text.isNotEmpty &&
        _selectedDay != 'Day' &&
        _selectedMonth != 'Month' &&
        _selectedYear != 'Year';

    // For home care, detailed address fields are required
    if (widget.isHomeCare) {
      basicValid = basicValid &&
          _addressLine1Controller.text.isNotEmpty &&
          _postcodeController.text.isNotEmpty &&
          _selectedArea != 'Select Area';
    }

    return basicValid;
  }

  Future<void> _saveBooking() async {
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
          content: Text('Please login to make a booking'),
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

      // Prepare patient details
      final patientDetails = {
        'nric': _nricController.text.trim(),
        'name': _nameController.text.trim(),
        'birthDate': birthDate,
        'gender': _selectedGender,
        'mobile': _mobileController.text.trim(),
        'email': _emailController.text.trim(),
      };

      // Add detailed address for home care
      if (widget.isHomeCare) {
        patientDetails['addressLine1'] = _addressLine1Controller.text.trim();
        patientDetails['addressLine2'] = _addressLine2Controller.text.trim();
        patientDetails['postcode'] = _postcodeController.text.trim();
        patientDetails['area'] = _selectedArea;

        // Create full address string for backward compatibility
        String fullAddress = _addressLine1Controller.text.trim();
        if (_addressLine2Controller.text.isNotEmpty) {
          fullAddress += ', ${_addressLine2Controller.text.trim()}';
        }
        fullAddress += ', ${_postcodeController.text.trim()} $_selectedArea, Penang';
        patientDetails['address'] = fullAddress;
      }

      setState(() {
        _isLoading = false;
      });

      // Navigate to payment page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentPage(
            doctorId: widget.doctorId,
            doctorData: widget.doctorData,
            patientDetails: patientDetails,
            selectedDate: widget.selectedDate,
            selectedTimeSlot: widget.selectedTimeSlot,
            isHomeCare: widget.isHomeCare,
          ),
        ),
      );

    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      print('Error preparing booking: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error preparing booking. Please try again.'),
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
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.thumb_up,
                    size: 40,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Thank You !',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.isHomeCare
                      ? 'Your Home Care Booking Successful'
                      : 'Your Appointment Successful',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.isHomeCare
                      ? 'You booked a home care service with ${widget.doctorData['name']} on ${DateFormat('MMMM d').format(widget.selectedDate)} for ${widget.selectedTimeSlot}'
                      : 'You booked an appointment with Dr. ${widget.doctorData['name']} on ${DateFormat('MMMM d').format(widget.selectedDate)} at ${widget.selectedTimeSlot}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog
                      Navigator.of(context).pop(); // Go back to previous screen
                      Navigator.of(context).pop(); // Go back to home care list
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
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
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
    if (!_hasPreviousBookings || _previousPatients.isEmpty) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          widget.isHomeCare
              ? 'Have you made a booking before?'
              : 'Have you made an appointment before?',
          style: const TextStyle(
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

  Widget _buildDetailedAddressFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          'Home Address',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),

        // Address Line 1
        _buildTextField(
          controller: _addressLine1Controller,
          hintText: 'Address Line 1 (Street, House Number)',
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter address line 1';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),

        // Address Line 2 (Optional)
        _buildTextField(
          controller: _addressLine2Controller,
          hintText: 'Address Line 2 (Optional)',
        ),
        const SizedBox(height: 12),

        // Postcode and Area
        Row(
          children: [
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Postcode',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildTextField(
                    controller: _postcodeController,
                    hintText: '11900',
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      if (value.length != 5) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Area',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildDropdown(
                    value: _selectedArea,
                    items: _penangAreas,
                    onChanged: (value) {
                      setState(() {
                        _selectedArea = value ?? 'Select Area';
                      });
                    },
                    hint: 'Select Area',
                  ),
                ],
              ),
            ),
          ],
        ),

        // State (Fixed to Penang)
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
            'Penang, Malaysia',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ),
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
        title: Text(
          widget.isHomeCare ? 'Patient Details' : 'Patient Details',
          style: const TextStyle(
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
                      // Previous patients section
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

                      // Detailed address fields for home care (Penang only)
                      if (widget.isHomeCare) _buildDetailedAddressFields(),
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
                onPressed: _isLoading ? null : _saveBooking,
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
                  'Proceed to Payment',
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