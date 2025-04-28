import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sib_expense_app/config/dio_client.dart'; // Import the helper

import 'add_employee_screen.dart';

class EmployeesScreen extends StatefulWidget {
  final String token;

  const EmployeesScreen({Key? key, required this.token}) : super(key: key);

  @override
  _EmployeesScreenState createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  List<Map<String, dynamic>> _employees = []; // Can hold one or many
  bool _isLoading = true;
  String? _errorMessage;
  String _userRole = '';
  int? _userId; // Store the logged-in user's ID

  final Dio _dio = createDioClient(); // Get the configured Dio instance


  @override
  void initState() {
    super.initState();
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        options.headers['Authorization'] = 'Bearer ${widget.token}';
        return handler.next(options);
      },
    ));
    _fetchUserRoleAndData();
  }

  Future<void> _fetchUserRoleAndData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? storedRole = prefs.getString('user_role');
    final int? storedUserId = prefs.getInt('user_id'); // Get user ID

    if (storedRole == null || storedUserId == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = "User role or ID not found. Please login again.";
      });
      return;
    }

    setState(() {
      _userRole = storedRole;
      _userId = storedUserId;
    });

    await _fetchUserData(); // Fetch data after getting role and ID
  }

  Future<void> _fetchUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    String endpoint;
    bool fetchList = false; // Flag to know if we expect a list or single object

    if (_userRole == 'ADMIN' || _userRole == 'MANAGER') {
      endpoint = '/api/admin/users'; // Endpoint for admins/managers
      fetchList = true;
    } else { // Assume EMPLOYEE role
      endpoint = '/api/users/me'; // Endpoint for employee's own profile
      // Or use ID: endpoint = '/api/users/$_userId';
      fetchList = false;
    }

    try {
      print('Fetching user data from endpoint: $endpoint');
      final response = await _dio.get(endpoint);

      if (response.statusCode == 200) {
        setState(() {
          if (fetchList) {
            // Expecting a list of users
            _employees = List<Map<String, dynamic>>.from(response.data);
          } else {
            // Expecting a single user object for '/api/users/me'
            if (response.data is Map<String, dynamic>) {
              _employees = [Map<String, dynamic>.from(response.data)]; // Put single user in a list
            } else {
              _errorMessage = 'Unexpected response format for user profile.';
              _employees = [];
            }
          }
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load user data: ${response.statusCode}';
        });
        print('Failed to load user data: ${response.statusCode}');
      }
    } on DioError catch (e) {
      setState(() {
        _errorMessage = 'Error fetching user data: ${e.message}';
        if (e.response != null) {
          print('Error response data: ${e.response?.data}');
          if (e.response?.statusCode == 403) {
            _errorMessage = 'Access Denied.';
          } else {
            _errorMessage = 'Error: ${e.response?.statusCode}';
          }
        } else {
          _errorMessage = 'Network Error.';
        }
      });
      print('Error fetching user data: $e');
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred: $e';
      });
      print('Unexpected error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // --- Update/Delete only relevant for ADMIN/MANAGER ---
  Future<void> _updateEmployee(Map<String, dynamic> employeeData) async {
    if (_userRole != 'ADMIN' && _userRole != 'MANAGER') return; // Extra check

    try {
      // **IMPORTANT:** Use the correct DTO structure expected by your backend
      //               for the /api/admin/users/{id} PUT endpoint.
      await _dio.put(
        '/api/admin/users/${employeeData['id']}', // Endpoint for admin/manager update
        data: employeeData, // Send the map, ensure keys match backend DTO
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      _fetchUserData(); // Refresh list
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User updated successfully')),
      );
    } catch (e) {
      print('Error updating employee: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating user: ${e.toString()}')),
      );
    }
  }

  Future<void> _deleteEmployee(int id) async { // Changed ID to int
    if (_userRole != 'ADMIN' && _userRole != 'MANAGER') return;

    bool confirmDelete = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete User'),
          content: const Text('Are you sure you want to delete this user?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
          ],
        );
      },
    ) ?? false;

    if (!confirmDelete) return;


    try {
      await _dio.delete(
        '/api/admin/users/$id', // Endpoint for admin/manager delete
      );
      _fetchUserData(); // Refresh list
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User deleted successfully')),
      );
    } catch (e) {
      print('Error deleting employee: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting user: ${e.toString()}')),
      );
    }
  }

  // --- Edit Dialog (Adapt for ADMIN/MANAGER vs EMPLOYEE) ---
  void _showEditDialog(Map<String, dynamic> employeeData) {
    bool isEditingSelf = (_userRole == 'EMPLOYEE' && employeeData['id'] == _userId);
    bool canAdminEdit = (_userRole == 'ADMIN' || _userRole == 'MANAGER');

    // Existing controllers
    final TextEditingController usernameController =
    TextEditingController(text: employeeData['username'] ?? '');
    final TextEditingController departmentController =
    TextEditingController(text: employeeData['department'] ?? '');
    final TextEditingController phoneController =
    TextEditingController(text: employeeData['phone'] ?? '');
    // Controllers only relevant for Admin/Manager editing others
    final TextEditingController roleController =
    TextEditingController(text: employeeData['role'] ?? '');
    final TextEditingController emailController =
    TextEditingController(text: employeeData['email'] ?? '');

    // --- NEW: Controllers for Password Change (only used when isEditingSelf) ---
    final TextEditingController oldPasswordController = TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController = TextEditingController();
    bool _obscureOld = true;
    bool _obscureNew = true;
    bool _obscureConfirm = true;
    // --- END NEW ---

    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Use StatefulBuilder for password visibility toggles inside the dialog
        return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(isEditingSelf ? 'Edit My Profile' : 'Edit User'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start, // Align labels
                    children: [
                      TextField(
                          controller: usernameController,
                          decoration: const InputDecoration(labelText: 'Username')),
                      // Department and Phone editable by all (self or admin/manager)
                      TextField(
                          controller: departmentController,
                          decoration: const InputDecoration(labelText: 'Department')),
                      TextField(
                          controller: phoneController,
                          decoration: const InputDecoration(labelText: 'Phone')),

                      // Fields only visible/editable by Admin/Manager editing OTHERS
                      if (canAdminEdit && !isEditingSelf) ...[
                        const SizedBox(height: 16),
                        TextField(
                            controller: emailController,
                            decoration: const InputDecoration(labelText: 'Email')),
                        TextField(
                            controller: roleController,
                            decoration: const InputDecoration(labelText: 'Role (EMPLOYEE/MANAGER)')),
                      ],

                      // Email shown read-only when editing self
                      if (isEditingSelf) ...[
                        const SizedBox(height: 16),
                        Text('Email: ${employeeData['email'] ?? 'N/A'}', style: TextStyle(color: Colors.grey[600])),
                      ],


                      // --- NEW: Password Change Section (only for editing self) ---
                      if (isEditingSelf) ...[
                        const SizedBox(height: 20),
                        const Divider(),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text('Change Password', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        TextFormField( // Use TextFormField for validation
                          controller: oldPasswordController,
                          obscureText: _obscureOld,
                          decoration: InputDecoration(
                            labelText: 'Current Password',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                                icon: Icon(_obscureOld ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setDialogState(() => _obscureOld = !_obscureOld)),
                          ),
                          validator: (value) {
                            // Only validate if new password fields are also filled
                            if (newPasswordController.text.isNotEmpty || confirmPasswordController.text.isNotEmpty) {
                              if (value == null || value.isEmpty) {
                                return 'Enter current password to change';
                              }
                            }
                            return null; // No error if not changing password
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: newPasswordController,
                          obscureText: _obscureNew,
                          decoration: InputDecoration(
                            labelText: 'New Password',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                                icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setDialogState(() => _obscureNew = !_obscureNew)),
                          ),
                          validator: (value) {
                            // Only validate if old password field is also filled
                            if (oldPasswordController.text.isNotEmpty) {
                              if (value == null || value.isEmpty) return 'Enter a new password';
                              if (value.length < 8) return 'Min 8 characters';
                              // Add more complexity rules if needed
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: confirmPasswordController,
                          obscureText: _obscureConfirm,
                          decoration: InputDecoration(
                            labelText: 'Confirm New Password',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                                icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setDialogState(() => _obscureConfirm = !_obscureConfirm)),
                          ),
                          validator: (value) {
                            // Only validate if new password field is also filled
                            if (newPasswordController.text.isNotEmpty) {
                              if (value == null || value.isEmpty) return 'Confirm your new password';
                              if (value != newPasswordController.text) return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                      ]
                      // --- END NEW ---

                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  ElevatedButton(
                    child: const Text('Save Changes'),
                    onPressed: () async { // Make async for potential password change call

                      // --- DEFINE updatedData HERE ---
                      Map<String, dynamic> updatedUserData = { // Renamed for clarity from backend DTOs
                        // ID might not be needed for /api/users/me, but good to have for admin update logic
                        'id': employeeData['id'],
                        'username': usernameController.text.trim(),
                        'department': departmentController.text.trim().isEmpty ? null : departmentController.text.trim(),
                        'phone': phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                      };
                      if (canAdminEdit && !isEditingSelf) {
                        // Only add role and email if Admin/Manager is editing another user
                        updatedUserData['role'] = roleController.text.trim().toUpperCase();
                        updatedUserData['email'] = emailController.text.trim();
                      }
                      // --- END DEFINITION ---


                      // Check if password change is requested (only for self-edit)
                      bool passwordChangeRequested = isEditingSelf &&
                          oldPasswordController.text.isNotEmpty &&
                          newPasswordController.text.isNotEmpty &&
                          confirmPasswordController.text.isNotEmpty;

                      // Validate the specific part of the form being submitted
                      bool canProceed = true; // Assume we can proceed unless validation fails
                      String validationErrorMsg = 'Please correct the errors.'; // Default validation error

                      if (passwordChangeRequested) {
                        // Manually trigger validation ONLY for password fields if requested
                        bool oldPassValid = oldPasswordController.text.isNotEmpty;
                        bool newPassValid = newPasswordController.text.isNotEmpty && newPasswordController.text.length >= 8;
                        bool confirmPassValid = confirmPasswordController.text == newPasswordController.text;

                        if (!oldPassValid) validationErrorMsg = 'Enter current password to change.';
                        else if (!newPassValid) validationErrorMsg = 'New password must be at least 8 characters.';
                        else if (!confirmPassValid) validationErrorMsg = 'New passwords do not match.';

                        canProceed = oldPassValid && newPassValid && confirmPassValid;

                        if (!canProceed){
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(validationErrorMsg), backgroundColor: Colors.red)
                          );
                          return; // Don't proceed if password fields invalid
                        }
                      }
                      // You might want to add validation for other fields here as well if needed
                      // using _formKey.currentState.validate() IF you wrap the dialog content in a Form

                      if (canProceed) {
                        bool closeDialog = true; // Assume dialog should close unless password change fails
                        bool profileUpdateAttempted = false;

                        // 1. Update Profile Info (if applicable)
                        if (isEditingSelf) {
                          await _updateMyProfile(updatedUserData); // Pass the defined map
                          profileUpdateAttempted = true;
                        } else if (canAdminEdit) {
                          await _updateEmployee(updatedUserData); // Pass the defined map
                          profileUpdateAttempted = true;
                        }

                        // 2. Change Password (if applicable and profile update was okay or not attempted)
                        // Note: You might want to only attempt password change if profile update succeeded.
                        // This current logic attempts both sequentially.
                        if (passwordChangeRequested) {
                          bool passwordChanged = await _changePasswordInDialog(
                              oldPasswordController.text, // Pass text directly
                              newPasswordController.text  // Pass text directly
                          );
                          if (!passwordChanged) {
                            closeDialog = false; // Keep dialog open if password change failed
                          }
                        }

                        if (closeDialog) {
                          Navigator.of(context).pop(); // Close dialog only if everything intended succeeded
                          if (profileUpdateAttempted) { // Refresh only if profile data could have changed
                            _fetchUserData(); // Refresh data in the background screen
                          }
                        }
                      }
                      // Removed the 'else' block for general validation failure as the password check handles it
                      // If you add full form validation, re-add an else here.
                    },
                  ),
                ],
              );
            }
        );
      },
    );
  }

  // --- NEW HELPER: Function to call password change API from dialog ---
  Future<bool> _changePasswordInDialog(String oldPassword, String newPassword) async {
    setState(() { _isLoading = true; _errorMessage = null; }); // Show loading indicator if desired
    bool success = false;
    try {
      final response = await _dio.put(
        '/api/users/me/change-password',
        data: { 'oldPassword': oldPassword, 'newPassword': newPassword },
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password changed successfully!'), backgroundColor: Colors.green)
        );
        success = true;
      } else {
        String errorMsg = response.data['error'] ?? 'Failed to change password.';
        ScaffoldMessenger.of(context).showSnackBar( // Show error in SnackBar
            SnackBar(content: Text(errorMsg), backgroundColor: Colors.red)
        );
      }
    } catch (e) {
      String errorMsg = 'An error occurred.';
      if (e is DioError && e.response?.data is Map && e.response?.data['error'] != null) {
        errorMsg = e.response?.data['error'];
      } else {
        errorMsg = e.toString();
      }
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red)
      );
      print('Change Password Error: $e');
    } finally {
      setState(() { _isLoading = false; }); // Hide loading
    }
    return success;
  }

  // --- NEW: Function to update logged-in user's profile ---
  Future<void> _updateMyProfile(Map<String, dynamic> updatedData) async {
    try {
      // **IMPORTANT:** Use the correct DTO structure expected by your backend
      //               for the /api/users/me PUT endpoint. It might not need the 'id' or 'role'.
      final response = await _dio.put(
        '/api/users/me', // Endpoint for updating self-profile
        data: { // Send only fields the user can update for themselves
          'username': updatedData['username'],
          'department': updatedData['department'],
          'phone': updatedData['phone'],
          // Add password fields if implemented
        },
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        _fetchUserData(); // Refresh the single profile view
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: ${response.statusCode}')),
        );
        print('Failed to update profile: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: ${e.toString()}')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    // Adjust AppBar Title based on role
    String appBarTitle = (_userRole == 'EMPLOYEE') ? 'My Profile' : 'Manage Users';

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        backgroundColor: Colors.blue[700],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Only show search bar for Admin/Manager
            if (_userRole == 'ADMIN' || _userRole == 'MANAGER')
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search Users...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
                ),
                onChanged: (value) {
                  // TODO: Implement search logic
                },
              ),
            if (_userRole == 'ADMIN' || _userRole == 'MANAGER')
              const SizedBox(height: 16.0),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center)))
                  : _employees.isEmpty
                  ? const Center(child: Text('No user data found.'))
                  : RefreshIndicator(
                onRefresh: _fetchUserData,
                child: ListView.builder(
                  itemCount: _employees.length,
                  itemBuilder: (context, index) {
                    final employee = _employees[index];
                    final employeeId = employee['id'] as int?; // Use int?

                    if (employeeId == null) {
                      print("Warning: Skipping employee with missing ID at index $index");
                      return const SizedBox.shrink();
                    }


                    // Determine if edit/delete should be possible for this item
                    bool canAdminManagerEditDelete = (_userRole == 'ADMIN' || _userRole == 'MANAGER');
                    // Determine if the current list item represents the logged-in user
                    bool isCurrentUser = (_userRole == 'EMPLOYEE' && employeeId == _userId);

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 5.0),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: ListTile(
                        title: Text(employee['username'] ?? 'Unknown'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Role: ${employee['role'] ?? 'N/A'}'),
                            Text('Department: ${employee['department'] ?? 'N/A'}'),
                            Text('Email: ${employee['email'] ?? 'N/A'}'),
                            Text('Phone: ${employee['phone'] ?? 'N/A'}'),
                          ],
                        ),
                        trailing: isCurrentUser // If it's the employee viewing their own profile
                            ? IconButton( // Show only edit icon for self
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          tooltip: 'Edit My Profile',
                          onPressed: () => _showEditDialog(employee),
                        )
                            : canAdminManagerEditDelete // If it's admin/manager viewing the list
                            ? PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 20),
                          tooltip: "Actions",
                          onSelected: (String choice) {
                            if (choice == 'Edit') {
                              _showEditDialog(employee);
                            } else if (choice == 'Delete') {
                              // Add confirmation dialog for delete
                              _deleteEmployee(employeeId); // Use checked employeeId
                            }
                          },
                          itemBuilder: (BuildContext context) {
                            return {'Edit', 'Delete'}.map((String choice) {
                              return PopupMenuItem<String>(
                                value: choice,
                                child: Text(choice),
                              );
                            }).toList();
                          },
                        )
                            : null, // No actions shown if employee views other users (which shouldn't happen with correct API calls)
                      ),
                    );
                  },
                ),
              ),
            ),
            // Hide pagination if only showing one user (employee view)
            if (_userRole == 'ADMIN' || _userRole == 'MANAGER')
            // TODO: Implement actual pagination logic here if API supports it
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(onPressed: null, child: Text('Previous')), // Disabled for now
                  Text('Page 1'), // Static for now
                  TextButton(onPressed: null, child: Text('Next')), // Disabled for now
                ],
              ),
          ],
        ),
      ),
      // Optional: FAB for Admins/Managers to add a new employee
      // Inside EmployeesScreen build method:

      floatingActionButton: (_userRole == 'ADMIN' || _userRole == 'MANAGER')
          ? FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              // Navigate to the new AddEmployeeScreen
              builder: (context) => AddEmployeeScreen(token: widget.token),
            ),
          ).then((success) { // Check if navigation returned true
            if (success == true) {
              _fetchUserData(); // Refresh the list if an employee was added
            }
          });
        },
        child: const Icon(Icons.add),
        tooltip: 'Add Employee',
        backgroundColor: Colors.blue[700], // Match AppBar color
      )
          : null, // No FAB for employees on this screen // No FAB for employees on this screen
    );
  }
}