import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'register_page.dart';
import 'login_page.dart';
import 'forgot_password_page.dart';
import 'doctor/doctor_register_page.dart';
import 'doctor/doctor_login_page.dart';
import 'doctor/doctor_home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
      initialRoute: '/doctor-register',
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/forgot-password': (context) => const ForgotPasswordPage(),
        '/doctor-register': (context) => const DoctorRegisterPage(),
        '/doctor-login': (context) => const DoctorLoginPage(),
        '/doctorHome': (context) => const DoctorHomePage(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
