import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mobile_app_development/nurse/nurse_home_page.dart';
import 'package:mobile_app_development/nurse/nurse_login_page.dart';
import 'package:mobile_app_development/nurse/nurse_register_page.dart';
import 'package:mobile_app_development/nurse/nurse_schedule_page.dart';
import 'firebase_options.dart';
import 'nurse/nurse_profile_page.dart';
import 'register_page.dart';
import 'login_page.dart';
import 'forgot_password_page.dart';
import 'doctor/doctor_register_page.dart';
import 'doctor/doctor_login_page.dart';
import 'doctor/doctor_home_page.dart';
import 'home_page.dart';
import 'book_appointment_page.dart';
import 'profile_page.dart';
import 'hospitals_list_page.dart';
import 'doctor/doctor_profile_page.dart';
import 'home_care_page.dart';
import 'booking_history_page.dart';
import 'doctor/doctor_news_page.dart';
import 'doctor/doctor_schedule_page.dart';
import 'medical_record_page.dart';
import 'doctor/doctor_medical_page.dart';
import 'nurse/nurse_medical_page.dart';
import 'nurse/nurse_contact_page.dart';
import 'doctor/doctor_contact_page.dart';
import 'doctor/doctor_terms_page.dart';
import 'nurse/nurse_terms_page.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mobile App Development',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/forgot-password': (context) => const ForgotPasswordPage(),
        '/doctor-register': (context) => const DoctorRegisterPage(),
        '/doctor-login': (context) => const DoctorLoginPage(),
        '/doctorHome': (context) => const DoctorHomePage(),
        '/userHome': (context) => const UserHomePage(),
        '/book-appointment': (context) => const BookAppointmentPage(),
        '/profile': (context) => const ProfilePage(),
        '/hospitals': (context) => const HospitalsListPage(),
        '/doctor-profile': (context) => const DoctorProfilePage(),
        '/home-care': (context) => const HomeCarePage(),
        '/booking-history': (context) => const BookingHistoryPage(),
        '/nurse-register': (context) => const NurseRegisterPage(),
        '/nurse-login': (context) => const NurseLoginPage(),
        '/nurseHome': (context) => const NurseHomePage(),
        '/nurse-profile': (context) => const NurseProfilePage(),
        '/doctor-news': (context) => const DoctorNewsPage(),
        '/doctor-schedule': (context) => const DoctorSchedulePage(),
        '/medical-records': (context) => const MedicalRecordsPage(),
        '/nurse-schedule': (context) => const NurseSchedulePage(),
        '/doctor-medical-records': (context) => const DoctorMedicalPage(),
        '/nurse-medical-records': (context) => const NurseMedicalPage(),
        '/nurse-contact': (context) => const NurseContactPage(),
        '/doctor-contact': (context) => const DoctorContactPage(),
        '/doctor-terms': (context) => const DoctorTermsPage(),
        '/nurse-terms': (context) => const NurseTermsPage(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
