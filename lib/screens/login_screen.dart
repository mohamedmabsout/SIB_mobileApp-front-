import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sib_expense_app/screens/dashboard_screen.dart';
import 'package:sib_expense_app/screens/dynamic_dashboard_screen.dart';
import 'package:sib_expense_app/screens/employee_dashboard.dart';
import 'package:sib_expense_app/screens/manager_dashboard.dart';
import 'package:sib_expense_app/screens/registration_screen.dart';
import 'package:sib_expense_app/config/dio_client.dart'; // Import the helper

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  final Dio _dio = createDioClient(); // Get the configured Dio instance


  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('jwt_token');
    final String? role = prefs.getString('user_role');

    if (token != null && token.isNotEmpty && role != null) {
      bool isValid = await _validateToken(token);
      if (isValid) {
        _redirectToDashboard(role, token);
      }
    }
  }

  Future<bool> _validateToken(String token) async {
    try {
      final response = await _dio.get(
        '/auth/validate',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Inside _LoginScreenState in login_screen.dart

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _dio.post(
        '/auth/login', // Uses baseUrl from Dio options
        data: {
          'email': _emailController.text.trim(),
          'password': _passwordController.text.trim(),
        },
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        print('Login Response Data: $data'); // Good for debugging

        // --- FIX HERE: Extract and Save User ID ---
        final String token = data['token'];
        final String role = data['role'];
        // Extract the user ID - it might be int or String depending on JSON parsing
        final dynamic userIdRaw = data['id']; // Use dynamic first

        if (userIdRaw == null) {
          print('ERROR: User ID not received from backend!');
          setState(() {
            _errorMessage = 'Login error: Missing user ID.';
          });
          return; // Stop login if ID is missing
        }

        int? userId;
        if (userIdRaw is int) {
          userId = userIdRaw;
        } else if (userIdRaw is String) {
          userId = int.tryParse(userIdRaw);
        } else if (userIdRaw is num) { // Handles potential double/num types
          userId = userIdRaw.toInt();
        }

        if (userId == null) {
          print('ERROR: Could not parse User ID from backend response! Received: $userIdRaw');
          setState(() {
            _errorMessage = 'Login error: Invalid user ID format.';
          });
          return; // Stop login if ID format is wrong
        }
        // --- End ID Extraction ---


        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', token);
        await prefs.setString('user_role', role);
        await prefs.setInt('user_id', userId); // Save the user ID as an integer
        // --- END FIX ---

        // Verify saving
        print('Saved user_id: ${prefs.getInt('user_id')}');
        print('Saved user_role: ${prefs.getString('user_role')}');
        print('Saved jwt_token: ${prefs.getString('jwt_token') != null ? "Exists" : "Missing"}');


        print('Login successful, redirecting...');
        _redirectToDashboard(role, token);

      } else {
        // Handle non-200 status codes more specifically if needed
        String errorMsg = 'Login failed.';
        // Check if the response body contains an 'error' key
        if (response.data is Map && response.data.containsKey('error')) {
          errorMsg = response.data['error'];
        } else if (response.statusMessage != null && response.statusMessage!.isNotEmpty) {
          errorMsg = response.statusMessage!;
        }
        setState(() {
          _errorMessage = '$errorMsg (Status: ${response.statusCode})';
        });
        print('Login failed with status: ${response.statusCode}, Message: ${response.data}');
      }
    } on DioError catch (e) { // Use DioError for Dio specific errors
      setState(() {
        _errorMessage = 'Error: ${e.message}';
        if (e.response != null) {
          print('Error response data: ${e.response?.data}');
          if (e.response?.statusCode == 401) {
            _errorMessage = 'Invalid email or password.';
          } else {
            _errorMessage = 'Server Error: ${e.response?.statusCode}';
          }
        } else {
          _errorMessage = 'Network Error: Could not connect.';
        }
      });
      print('Login DioError: $e');
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred: ${e.toString()}';
      });
      print('Login General Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _redirectToDashboard(String role, String token) {
    Widget dashboard;

    switch (role) {
      case 'EMPLOYEE':
        dashboard = EmployeeDashboard(token: token);
        break;
      case 'MANAGER':
        dashboard = ManagerDashboard(token: token);
        break;
      case 'ADMIN':
        dashboard = DynamicDashboardScreen(token: token);
        break;
      default:
        setState(() {
          _errorMessage = 'Invalid role. Please contact support.';
        });
        return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => dashboard),
          (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Image.asset(
            'assets/background.jpeg',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/logo.png',
                          height: 100,
                        ),
                        const SizedBox(height: 32.0),
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white70,
                          ),
                          validator: (value) =>
                          value == null || value.isEmpty ? 'Please enter your email' : null,
                        ),
                        const SizedBox(height: 16.0),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white70,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          validator: (value) =>
                          value == null || value.isEmpty ? 'Please enter your password' : null,
                        ),

                        const SizedBox(height: 24.0),
                        if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          child: _isLoading
                              ? const CircularProgressIndicator()
                              : const Text('Login'),
                        ),
                        const SizedBox(height: 8.0),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const RegistrationScreen()),
                            );
                          },
                          child: const Text('Need an account? Register'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
