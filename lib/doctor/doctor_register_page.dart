import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class DoctorRegisterPage extends StatefulWidget {
  const DoctorRegisterPage({super.key});

  @override
  State<DoctorRegisterPage> createState() => _DoctorRegisterPageState();
}

class _DoctorRegisterPageState extends State<DoctorRegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController doctorIdController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController specializationController = TextEditingController();
  final TextEditingController hospitalController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _isSubmitting = false;
  bool _isPasswordVisible = false;

  XFile? pickedImage;
  Uint8List? imageBytes;
  final ImagePicker picker = ImagePicker();

  final String cloudName = 'darvkev9g';
  final String uploadPreset = 'doctor_image';

  @override
  void dispose() {
    doctorIdController.dispose();
    nameController.dispose();
    specializationController.dispose();
    hospitalController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> pickImage() async {
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (image != null) {
      setState(() {
        pickedImage = image;
      });
      imageBytes = await image.readAsBytes();
    }
  }

  Future<String> uploadImageToCloudinary(XFile image) async {
    final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = uploadPreset;

    if (kIsWeb) {
      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        await image.readAsBytes(),
        filename: image.name,
        contentType: MediaType('image', 'jpeg'),
      );
      request.files.add(multipartFile);
    } else {
      request.files.add(await http.MultipartFile.fromPath('file', image.path));
    }

    final response = await request.send();
    final respStr = await response.stream.bytesToString();
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Image upload failed: $respStr');
    }

    return jsonDecode(respStr)['secure_url'];
  }

  Future<void> _submitDoctor() async {
    if (!_formKey.currentState!.validate()) return;

    if (pickedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a profile image"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final doctorId = doctorIdController.text.trim();

    try {
      // Check if doctorId exists
      final existing = await FirebaseFirestore.instance
          .collection('doctors')
          .where('doctorId', isEqualTo: doctorId)
          .get();
      if (existing.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Doctor ID already exists"),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      // Create Firebase Auth user
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final imageUrl = await uploadImageToCloudinary(pickedImage!);

      // Default weeklySessions data
      final Map<String, dynamic> defaultWeeklySessions = {
        "Monday": [
          {"start": "08:00", "end": "13:00"},
          {"start": "14:00", "end": "17:00"},
        ],
        "Tuesday": [
          {"start": "08:00", "end": "13:00"},
          {"start": "14:00", "end": "17:00"},
        ],
        "Wednesday": [
          {"start": "08:00", "end": "13:00"},
          {"start": "14:00", "end": "17:00"},
        ],
        "Thursday": [
          {"start": "08:00", "end": "13:00"},
          {"start": "14:00", "end": "17:00"},
        ],
        "Friday": [
          {"start": "08:00", "end": "13:00"},
          {"start": "14:00", "end": "17:00"},
        ],
        "Saturday": [],
        "Sunday": [],
      };

      // Save doctor data with default weeklySessions
      await FirebaseFirestore.instance.collection('doctors').doc(userCredential.user!.uid).set({
        'doctorId': doctorId,
        'name': nameController.text.trim(),
        'specialization': specializationController.text.trim(),
        'hospital': hospitalController.text.trim(),
        'email': email,
        'phone': phoneController.text.trim(),
        'imageUrl': imageUrl,
        'weeklySessions': defaultWeeklySessions,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Doctor registered successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacementNamed(context, '/doctor-login');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is FirebaseAuthException ? e.message ?? 'Error' : 'Unexpected error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildDoubleField(Widget leftField, Widget rightField) {
    return Row(
      children: [
        Expanded(child: leftField),
        const SizedBox(width: 16),
        Expanded(child: rightField),
      ],
    );
  }

  Widget _buildField(TextEditingController controller, String hint,
      {bool obscure = false,
        Widget? suffixIcon,
        TextInputType? keyboardType,
        String? Function(String?)? validator}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 16),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
          suffixIcon: suffixIcon,
        ),
        validator: validator ??
                (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter $hint';
              }
              return null;
            },
      ),
    );
  }

  ImageProvider? get _profileImage {
    if (pickedImage == null) return null;
    if (kIsWeb) {
      if (imageBytes == null) return null;
      return MemoryImage(imageBytes!);
    } else {
      return FileImage(File(pickedImage!.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE3F2FD),
              Color(0xFFF3E5F5),
              Color(0xFFFFFFFF),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Doctor Registration',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2C3E50),
                              ),
                            ),
                            const SizedBox(height: 20),
                            GestureDetector(
                              onTap: pickImage,
                              child: CircleAvatar(
                                radius: 60,
                                backgroundColor: const Color(0xFFF2ECF3),
                                backgroundImage: _profileImage,
                                child: _profileImage == null
                                    ? const Icon(Icons.camera_alt, size: 40, color: Colors.grey)
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildDoubleField(
                              _buildField(doctorIdController, 'Doctor ID'),
                              _buildField(nameController, 'Doctor Name'),
                            ),
                            const SizedBox(height: 16),
                            _buildDoubleField(
                              _buildField(specializationController, 'Specialization'),
                              _buildField(hospitalController, 'Hospital'),
                            ),
                            const SizedBox(height: 16),
                            _buildDoubleField(
                              _buildField(emailController, 'Email',
                                  keyboardType: TextInputType.emailAddress),
                              _buildField(phoneController, 'Phone Number',
                                  keyboardType: TextInputType.phone),
                            ),
                            const SizedBox(height: 16),
                            _buildField(
                              passwordController,
                              'Password',
                              obscure: !_isPasswordVisible,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                  color: const Color(0xFFBDBDBD),
                                ),
                                onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                              ),
                            ),
                            const SizedBox(height: 30),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isSubmitting ? null : _submitDoctor,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2196F3),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isSubmitting
                                    ? const CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2)
                                    : const Text(
                                  'Register Doctor',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextButton(
                              onPressed: () {
                                Navigator.pushReplacementNamed(context, '/doctor-login');
                              },
                              child: RichText(
                                text: const TextSpan(
                                  text: 'Have an account? ',
                                  style: TextStyle(
                                    color: Color(0xFF757575),
                                    fontSize: 16,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: 'Log in',
                                      style: TextStyle(
                                        color: Color(0xFF2196F3),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
