import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sib_expense_app/screens/login_screen.dart'; // For logout redirection
import 'package:sib_expense_app/config/dio_client.dart'; // Import the helper

class EditProfileScreen extends StatefulWidget {
  final String token;

  const EditProfileScreen({Key? key, required this.token}) : super(key: key);

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _profileFormKey = GlobalKey<FormState>(); // Key for profile fields
  final _passwordFormKey = GlobalKey<FormState>(); // Key for password fields

  // Controllers for profile data
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController(); // Usually read-only
  final _departmentController = TextEditingController();
  final _phoneController = TextEditingController();

  // Controllers for password change
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoadingData = true; // Loading initial profile data
  bool _isSavingProfile = false;
  bool _isChangingPassword = false;
  String? _errorMessage;
  String? _successMessage;

  // Password visibility toggles
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  final Dio _dio = createDioClient(); // Get the configured Dio instance


  @override
  void initState() {
    super.initState();
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        options.headers['Authorization'] = 'Bearer ${widget.token}';
        options.headers['Content-Type'] = 'application/json';
        return handler.next(options);
      },
    ));
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoadingData = true;
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      final response = await _dio.get('/api/users/me');
      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        setState(() {
          _usernameController.text = data['username'] ?? '';
          _emailController.text = data['email'] ?? ''; // Display email
          _departmentController.text = data['department'] ?? '';
          _phoneController.text = data['phone'] ?? '';
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load profile (${response.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading profile: ${e.toString()}';
      });
      print("Error loading profile: $e");
    } finally {
      setState(() {
        _isLoadingData = false;
      });
    }
  }

  Future<void> _updateProfile() async {
    if (!_profileFormKey.currentState!.validate()) return;

    setState(() {
      _isSavingProfile = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final response = await _dio.put(
        '/api/users/me',
        data: { // Send only fields the user can update
          'username': _usernameController.text.trim(),
          'department': _departmentController.text.trim().isEmpty ? null : _departmentController.text.trim(),
          'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        },
      );

      if (response.statusCode == 200) {
        setState(() { _successMessage = 'Profile updated successfully!'; });
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile Updated'), backgroundColor: Colors.green)
        );
        // Optionally reload profile data if backend returns updated info
        // _loadUserProfile();
      } else {
        _handleApiError(response, 'Failed to update profile');
      }

    } catch(e){
      _handleGenericError(e, "updating profile");
    } finally {
      setState(() { _isSavingProfile = false; });
    }
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return; // Use password form key

    setState(() {
      _isChangingPassword = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final response = await _dio.put(
        '/api/users/me/change-password',
        data: {
          'oldPassword': _oldPasswordController.text, // Key names MUST match backend DTO
          'newPassword': _newPasswordController.text,
        },
      );

      if (response.statusCode == 200) {
        setState(() { _successMessage = 'Password changed successfully!'; });
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password Changed'), backgroundColor: Colors.green)
        );
        // Clear password fields after successful change
        _oldPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        FocusScope.of(context).unfocus(); // Hide keyboard
      } else {
        _handleApiError(response, 'Failed to change password');
      }

    } catch (e) {
      _handleGenericError(e, "changing password");
    } finally {
      setState(() { _isChangingPassword = false; });
    }
  }

  Future<void> _logout() async {
    // Clear JWT, role, id from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_role');
    await prefs.remove('user_id');

    // Navigate back to the LoginScreen and remove all previous routes
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false, // Remove all routes
    );
  }

  // --- Helper for API Error Handling ---
  void _handleApiError(Response? response, String defaultMessage) {
    if (!mounted) return;
    String errorMsg = defaultMessage;
    if (response?.data is Map && response!.data.containsKey('error')) {
      errorMsg = response.data['error'];
    } else if (response?.statusMessage != null && response!.statusMessage!.isNotEmpty) {
      errorMsg = response.statusMessage!;
    } else if (response?.data != null){
      errorMsg = response!.data.toString();
    }
    setState(() {
      _errorMessage = '$errorMsg (Status: ${response?.statusCode ?? 'N/A'})';
      _successMessage = null; // Clear success message on error
    });
    print('$defaultMessage: ${response?.statusCode}, Response: ${response?.data}');
  }

  // --- Helper for Generic Error Handling ---
  void _handleGenericError(Object e, String action) {
    if (!mounted) return;
    String errorMsg = 'Error $action: ${e.toString()}';
    if (e is DioError) { // Correct Type
      if (e.response != null && e.response?.data is Map && e.response?.data['error'] != null) {
        errorMsg = e.response?.data['error'];
      } else if (e.response != null && e.response?.data != null) {
        errorMsg = "Server Error (${e.response?.statusCode}): ${e.response?.data.toString().substring(0,100)}...";
      }
      else if (e.response != null) {
        errorMsg = 'Server Error: ${e.response?.statusCode}';
      }
      else {
        errorMsg = 'Network Error. Please check connection.';
      }
    }
    setState(() {
      _errorMessage = errorMsg;
      _successMessage = null; // Clear success message on error
    });
    print('Error $action: $e');
  }


  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _departmentController.dispose();
    _phoneController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit My Profile'),
        backgroundColor: Colors.blue[700],
      ),
      body: Stack(
        children: [
          Image.asset( // Optional background
            'assets/background.jpeg',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
          SafeArea(
            child: _isLoadingData
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView( // Use SingleChildScrollView for content
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- Profile Information Section ---
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Form(
                        key: _profileFormKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Profile Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _usernameController,
                              decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder()),
                              validator: (value) => value == null || value.isEmpty ? 'Username is required' : null,
                            ),
                            const SizedBox(height: 12),
                            // Email - Display only, not editable
                            TextFormField(
                              controller: _emailController,
                              readOnly: true, // Make email read-only
                              decoration: InputDecoration(
                                labelText: 'Email (Read-Only)',
                                border: const OutlineInputBorder(),
                                fillColor: Colors.grey[200], // Indicate read-only
                                filled: true,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _departmentController,
                              decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 20),
                            Center( // Center the save button
                              child: ElevatedButton(
                                onPressed: _isSavingProfile ? null : _updateProfile,
                                child: _isSavingProfile
                                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Text('Save Profile Changes'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- Change Password Section ---
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Form(
                        key: _passwordFormKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Change Password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _oldPasswordController,
                              obscureText: _obscureOld,
                              decoration: InputDecoration(
                                labelText: 'Current Password',
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                    icon: Icon(_obscureOld ? Icons.visibility_off : Icons.visibility),
                                    onPressed: () => setState(() => _obscureOld = !_obscureOld)),
                              ),
                              validator: (value) {
                                if (_newPasswordController.text.isNotEmpty || _confirmPasswordController.text.isNotEmpty) {
                                  if (value == null || value.isEmpty) return 'Required to change password';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _newPasswordController,
                              obscureText: _obscureNew,
                              decoration: InputDecoration(
                                labelText: 'New Password',
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                    icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility),
                                    onPressed: () => setState(() => _obscureNew = !_obscureNew)),
                              ),
                              validator: (value) {
                                if (_oldPasswordController.text.isNotEmpty) {
                                  if (value == null || value.isEmpty) return 'Enter new password';
                                  if (value.length < 8) return 'Min 8 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirm,
                              decoration: InputDecoration(
                                labelText: 'Confirm New Password',
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                    icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm)),
                              ),
                              validator: (value) {
                                if (_newPasswordController.text.isNotEmpty) {
                                  if (value != _newPasswordController.text) return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            Center(
                              child: ElevatedButton(
                                onPressed: _isChangingPassword ? null : _changePassword,
                                child: _isChangingPassword
                                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Text('Change Password'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- Error/Success Message Display ---
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (_successMessage != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        _successMessage!,
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),


                  const SizedBox(height: 32),

                  // --- Logout Button ---
                  Center(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
                      onPressed: _logout,
                    ),
                  ),
                  const SizedBox(height: 20), // Bottom padding
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}