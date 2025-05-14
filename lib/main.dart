import 'package:flutter/material.dart';
import 'package:sib_expense_app/screens/login_screen.dart';
import 'package:sib_expense_app/screens/employees_screen.dart';

import 'config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- LOAD CONFIGURATION ---
  // Optionally determine environment (e.g., from --dart-define, default to 'dev')
  const String environment = String.fromEnvironment('APP_ENV', defaultValue: 'dev');
  await AppConfig.load(environment);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SIB Expense App',
      debugShowCheckedModeBanner: true,

      theme: ThemeData(
        primarySwatch: Colors.blue,
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.blue, // Base color scheme on blue
          accentColor: Colors.teal, // Example accent color (used for FABs, etc.)
          // errorColor: Colors.red[700], // Example error color
          // backgroundColor: const Color(0xFFF5F5F5), // Default background
          // brightness: Brightness.light, // Or Brightness.dark
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            // Default border color will now be based on primarySwatch/colorScheme
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            // Focused border color will use primaryColor/accentColor
            borderSide: BorderSide(color: Colors.blue[700]!, width: 2.0), // Explicitly blue focused border
          ),
          // You can customize filledColor, labelStyle etc. here too
          // filled: true,
          // fillColor: Colors.blue.withOpacity(0.05),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[700], // Button background
            foregroundColor: Colors.white, // Button text/icon color
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          ),
        ),
        cardTheme: CardTheme(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4) // Default card margin
        ),

        // Define other theme aspects like text styles if desired
        // textTheme: TextTheme(...)

        // Ensure widgets use the theme's primary color by default
        useMaterial3: true,
      ),

      // Système de navigation par routes nommées
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/employees': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>;
          return EmployeesScreen(token: args['token']);
        },
      },
    );
  }
}