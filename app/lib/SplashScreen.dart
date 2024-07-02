// import 'package:flutter/material.dart';
// import 'HomePage.dart'; // Import the home page

// class MySplashScreen extends StatefulWidget {
//   @override
//   _MySplashScreenState createState() => _MySplashScreenState();
// }

// class _MySplashScreenState extends State<MySplashScreen> {
//   @override
//   void initState() {
//     super.initState();
//     _navigateToHome();
//   }

//   _navigateToHome() async {
//     await Future.delayed(Duration(seconds: 3), () {});
//     Navigator.pushReplacement(
//         context, MaterialPageRoute(builder: (context) => HomePage()));
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Image.asset('assets/robot.jpeg', height: 100.0),
//             SizedBox(height: 20),
//             CircularProgressIndicator(
//               valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
