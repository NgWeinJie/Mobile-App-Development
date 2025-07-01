import 'package:flutter/material.dart';

class NurseTermsPage extends StatelessWidget {
  const NurseTermsPage({super.key});

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
              style: const TextStyle(fontSize: 16, color: Colors.black, height: 1.5),
              children: const [
                TextSpan(
                  text:
                  'Welcome to the Nurse Portal of the Clinic App. By accessing and using this application, you agree to the following terms and conditions:\n\n',
                ),
                TextSpan(
                  text: '1. Purpose of Use\n',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                TextSpan(
                  text:
                  'This portal is designed exclusively for registered nurses affiliated with the clinic. It allows nurses to manage bookings, view patient information, and update their availability and profile.\n\n',
                ),
                TextSpan(
                  text: '2. Account Security\n',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                TextSpan(
                  text:
                  'You are responsible for securing your account credentials. Any activity carried out using your account will be considered your responsibility.\n\n',
                ),
                TextSpan(
                  text: '3. Patient Data Confidentiality\n',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                TextSpan(
                  text:
                  'All patient records accessed via this portal are confidential. You are expected to comply with medical and legal standards regarding data protection. Unauthorized disclosure is strictly prohibited.\n\n',
                ),
                TextSpan(
                  text: '4. Professional Responsibility\n',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                TextSpan(
                  text:
                  'All actions and updates made via this platform must reflect accurate and honest information. You are responsible for maintaining professionalism and integrity.\n\n',
                ),
                TextSpan(
                  text: '5. System Usage\n',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                TextSpan(
                  text:
                  'The app must not be misused to tamper with data, breach security, or perform any unauthorized activities. Such actions may lead to disciplinary or legal consequences.\n\n',
                ),
                TextSpan(
                  text: '6. Updates to Terms\n',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                TextSpan(
                  text:
                  'These terms may be revised periodically. Continued use of the app constitutes acceptance of any changes made.\n\n',
                ),
                TextSpan(
                  text: '7. Termination\n',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                TextSpan(
                  text:
                  'Violations of these terms may result in suspension or permanent removal of access to the portal.\n\n',
                ),
                TextSpan(
                  text:
                  'If you have any questions or concerns, please contact our support team at support@clinicapp.my.\n\nThank you for your service and dedication to quality patient care.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
