// import 'package:flutter/material.dart';
//
// class SplashScreen extends StatefulWidget {
//   final VoidCallback onInitializationComplete;
//
//   const SplashScreen({required this.onInitializationComplete, Key? key})
//       : super(key: key);
//
//   @override
//   _SplashScreenState createState() => _SplashScreenState();
// }
//
// class _SplashScreenState extends State<SplashScreen> {
//   @override
//   void initState() {
//     super.initState();
//     // Start a timer to navigate after splash
//     Future.delayed(const Duration(seconds: 3), () {
//       widget.onInitializationComplete();
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: Center(
//         child: Image.asset(
//           'assets/logo.png', // Replace with your logo path
//           width: 150,
//         ),
//       ),
//     );
//   }
// }
