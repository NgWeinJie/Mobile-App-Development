import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';


Future<void> main() async{

  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: 'AIzaSyCaQSN5ehylYNRjn2GTVZYxWxpARMer7zA',
      appId: '1:420055386320:android:867e5b39db2860547176d5',
      messagingSenderId: '420055386320',
      projectId: 'mobile-app-development-78ac2',
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
    );
  }
}

