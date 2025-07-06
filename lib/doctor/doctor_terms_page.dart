import 'package:flutter/material.dart';

class DoctorTermsPage extends StatelessWidget {
  const DoctorTermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Conditions', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1976D2),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 16, color: Colors.black),
              children: [
                TextSpan(
                  text:
                  'Welcome to the Doctor Portal of the HealthConnect App. By accessing and using this application, you agree to the following terms and conditions:\n\n',
                ),
                TextSpan(text: 'Purpose of Use\n\n', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(
                  text:
                  'This portal is intended for licensed doctors affiliated with the clinic to manage appointments, view patient medical records, and update their availability and profile.\n\n\n',
                ),
                TextSpan(text: 'Account Responsibility\n\n', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(
                  text:
                  'You are responsible for maintaining the confidentiality of your login credentials. Any activity that occurs under your account will be your sole responsibility.\n\n\n',
                ),
                TextSpan(text: 'Data Confidentiality\n\n', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(
                  text:
                  'All patient information accessed through this platform is strictly confidential and must comply with data protection laws. You are prohibited from sharing, disclosing, or distributing any patient data without proper authorization.\n\n\n',
                ),
                TextSpan(text: 'Medical Advice and Liability\n\n', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(
                  text:
                  'The app serves only as a tool to facilitate your workflow. The clinic is not liable for any medical decisions or actions taken based on the data displayed in the app.\n\n\n',
                ),
                TextSpan(text: 'Content Accuracy\n\n', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(
                  text:
                  'While we strive to provide accurate and up-to-date information, the clinic does not guarantee the correctness or completeness of the data provided.\n\n\n',
                ),
                TextSpan(text: 'Prohibited Conduct\n\n', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(
                  text:
                  'Doctors must not misuse the app to upload harmful content, attempt to breach security features, or conduct activities that could harm the system or other users.\n\n\n',
                ),
                TextSpan(text: 'Modification of Terms\n\n', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(
                  text:
                  'These terms may be updated from time to time. Continued use of the app implies acceptance of the latest terms.\n\n\n',
                ),
                TextSpan(text: 'Termination of Access\n\n', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(
                  text:
                  'Violation of these terms may result in suspension or permanent termination of access to the Doctor Portal.\n\n',
                ),
                TextSpan(
                  text:
                  'If you have any questions regarding these terms, please contact the administration at support@clinicapp.my.\n\nThank you for your cooperation and for providing professional care to our patients.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
